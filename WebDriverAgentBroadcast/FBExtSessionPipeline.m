/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBExtSessionPipeline.h"

#include <time.h>

#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

#import "FBBroadcastProtocol.h"
#import "FBExtLogging.h"
#import "FBVideoEncoder.h"

static NSString *const FBExtPipelineErrorDomain = @"com.facebook.WebDriverAgent.FBExtSessionPipeline";

// Bounds the scaled-buffer pool so a stuck consumer cannot grow the extension past its ~50MB cap.
static const int POOL_ALLOCATION_THRESHOLD = 4;

@interface FBExtSessionPipeline () <FBVideoEncoderDelegate> {
  CMSampleBufferRef _pendingSampleBuffer;
  /** The most recently encoded (pool-owned) frame, re-encoded to fill delivery gaps (queue-confined). */
  CVPixelBufferRef _repeatBuffer;
}

@property (nonatomic, weak) id<FBExtMessageSink> sink;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, nullable) FBVideoEncoder *encoder;
@property (nonatomic) VTPixelTransferSessionRef transferSession;
@property (nonatomic) CVPixelBufferPoolRef bufferPool;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;
@property (nonatomic) NSUInteger fps;
@property (nonatomic) uint64_t lastSubmitTimeMs;
/** The next monotonic timestamp at which a frame is due (fps gate accumulator). */
@property (nonatomic) uint64_t nextDueMs;
@property (nonatomic) BOOL inFlight;
@property (nonatomic) uint64_t pendingSubmitTimeMs;
@property (nonatomic) uint8_t pendingOrientation;
@property (atomic) BOOL active;
@property (atomic) uint8_t currentOrientation;
@property (nonatomic) BOOL directSourceEncodingDisabled;
@property (nonatomic, nullable, copy) NSData *lastSentParameterSets;

// Lightweight diagnostics, exposed via metricsSnapshot/the heartbeat. Increments are not
// strictly atomic RMW, which is acceptable for metrics.
@property (atomic) uint64_t samplesInCount;
@property (atomic) uint64_t acceptedCount;
@property (atomic) uint64_t encodedCount;
@property (atomic) uint64_t droppedFpsGateCount;
@property (atomic) uint64_t droppedReplacedCount;
@property (atomic) uint64_t droppedPoolCount;
@property (atomic) uint64_t repeatedCount;
@property (atomic) uint64_t lastEncodeLatencyMs;
@property (atomic) double avgEncodeLatencyMs;

// Frame repeater state (queue-confined except the timer handle).
@property (nonatomic, nullable) dispatch_source_t repeatTimer;
@property (nonatomic) uint64_t frameIntervalMs;
@property (nonatomic) uint64_t lastEncodeAtMs;

- (void)replacePendingSampleBuffer:(CMSampleBufferRef)sampleBuffer
                           atTimeMs:(uint64_t)nowMs
                        orientation:(uint8_t)orientation;
- (nullable CMSampleBufferRef)copyPendingSampleBufferAtTimeMs:(uint64_t *)timeMs
                                                  orientation:(uint8_t *)orientation;
- (void)clearPendingSampleBufferLocked;

@end

@implementation FBExtSessionPipeline

- (nullable instancetype)initWithSessionId:(uint32_t)sessionId
                             configuration:(NSDictionary<NSString *, id> *)configuration
                                      sink:(id<FBExtMessageSink>)sink
                                     error:(NSError **)error
{
  if ((self = [super init])) {
    _sessionId = sessionId;
    _sink = sink;
    _queue = dispatch_queue_create([NSString stringWithFormat:@"wda.broadcast.session.%u", sessionId].UTF8String,
                                   DISPATCH_QUEUE_SERIAL);

    NSUInteger width = [configuration[FBBroadcastKeyWidth] unsignedIntegerValue];
    NSUInteger height = [configuration[FBBroadcastKeyHeight] unsignedIntegerValue];
    // Hardware encoders require even dimensions (same rule as the WDA-side converter).
    width -= width % 2;
    height -= height % 2;
    NSUInteger bitrate = [configuration[FBBroadcastKeyBitrate] unsignedIntegerValue];
    NSUInteger fps = [configuration[FBBroadcastKeyFps] unsignedIntegerValue];
    NSString *codecName = [configuration[FBBroadcastKeyCodec] isKindOfClass:NSString.class]
      ? (NSString *)configuration[FBBroadcastKeyCodec]
      : @"";
    FBVideoCodec codec = [FBBroadcastCodecH265 isEqualToString:codecName]
      ? FBVideoCodecH265
      : FBVideoCodecH264;
    if (width == 0 || height == 0) {
      if (error) {
        *error = [NSError errorWithDomain:FBExtPipelineErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Session configuration is missing positive 'width'/'height'"}];
      }
      return nil;
    }
    _fps = fps;
    _width = width;
    _height = height;

    OSStatus status = VTPixelTransferSessionCreate(kCFAllocatorDefault, &_transferSession);
    if (status != noErr || NULL == _transferSession) {
      if (error) {
        *error = [NSError errorWithDomain:FBExtPipelineErrorDomain
                                     code:status
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create a pixel transfer session (status %d)", (int)status]}];
      }
      return nil;
    }
    // Letterbox to preserve the aspect ratio, matching the WDA-side screenshot converter.
    VTSessionSetProperty(_transferSession, kVTPixelTransferPropertyKey_ScalingMode, kVTScalingMode_Letterbox);
    VTSessionSetProperty(_transferSession, kVTPixelTransferPropertyKey_RealTime, kCFBooleanTrue);

    NSDictionary *pixelBufferAttributes = @{
      (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
      (id)kCVPixelBufferWidthKey: @(width),
      (id)kCVPixelBufferHeightKey: @(height),
      (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    NSDictionary *poolAttributes = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @(POOL_ALLOCATION_THRESHOLD)};
    CVReturn poolStatus = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                                  (__bridge CFDictionaryRef)poolAttributes,
                                                  (__bridge CFDictionaryRef)pixelBufferAttributes,
                                                  &_bufferPool);
    if (poolStatus != kCVReturnSuccess || NULL == _bufferPool) {
      VTPixelTransferSessionInvalidate(_transferSession);
      CFRelease(_transferSession);
      _transferSession = NULL;
      if (error) {
        *error = [NSError errorWithDomain:FBExtPipelineErrorDomain
                                     code:poolStatus
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create a pixel buffer pool (status %d)", (int)poolStatus]}];
      }
      return nil;
    }

    FBVideoEncoder *encoder = [[FBVideoEncoder alloc] initWithCodec:codec
                                                              width:width
                                                             height:height
                                                            bitrate:bitrate > 0 ? bitrate : 6000000
                                                                fps:fps > 0 ? fps : 30
                                                              error:error];
    if (nil == encoder) {
      [self releaseScalerResources];
      return nil;
    }
    encoder.delegate = self;
    _encoder = encoder;
    _active = YES;
    // Open every session with an IDR: WDA only switches a stream onto the broadcast source once
    // a key frame (with parameter sets) has arrived.
    [encoder requestKeyFrame];

    // ReplayKit delivers nothing while the screen is static and VideoToolbox has no
    // Android-style repeat-previous-frame mode, so the last frame is re-encoded manually to
    // keep the output cadence at the requested fps.
    _frameIntervalMs = fps > 0 ? (uint64_t)(1000 / fps) : 0;
    if (_frameIntervalMs > 1) {
      [self startRepeatTimer];
    }
  }
  return self;
}

- (void)startRepeatTimer
{
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
  if (nil == timer) {
    return;
  }
  uint64_t intervalNs = self.frameIntervalMs * NSEC_PER_MSEC;
  dispatch_source_set_timer(timer,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)intervalNs),
                            intervalNs,
                            intervalNs / 4);
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(timer, ^{
    [weakSelf repeatLastFrameIfIdle];
  });
  dispatch_resume(timer);
  self.repeatTimer = timer;
}

- (void)repeatLastFrameIfIdle
{
  // Runs on self.queue, serialized with live encodes.
  if (!self.active || NULL == _repeatBuffer || 0 == self.lastEncodeAtMs) {
    return;
  }
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  if (nowMs - self.lastEncodeAtMs < self.frameIntervalMs) {
    return;
  }
  NSError *error;
  if ([self.encoder encodePixelBuffer:_repeatBuffer presentationTimeMs:nowMs error:&error]) {
    self.repeatedCount += 1;
    self.lastEncodeAtMs = nowMs;
  } else {
    FBExtLogError("Session %u: cannot re-encode the repeat frame: %{public}@",
                  self.sessionId, error.description);
  }
}

// Runs on self.queue. Retains the given pool-owned buffer as the repeat source.
- (void)storeRepeatBuffer:(CVPixelBufferRef)buffer
{
  if (buffer == _repeatBuffer) {
    return;
  }
  CVPixelBufferRef previous = _repeatBuffer;
  _repeatBuffer = (CVPixelBufferRef)CFRetain(buffer);
  if (NULL != previous) {
    CVPixelBufferRelease(previous);
  }
}

// Runs on self.queue. Copies a non-pool source (direct-encode path) into a pool buffer for the
// repeater: ReplayKit recycles its sample buffers, so retaining one would stall its capture.
- (void)refreshRepeatBufferWithCopyOf:(CVPixelBufferRef)sourceBuffer
{
  CVPixelBufferRef copyBuffer = NULL;
  NSDictionary *auxAttributes = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @(POOL_ALLOCATION_THRESHOLD)};
  CVReturn poolStatus = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,
                                                                            self.bufferPool,
                                                                            (__bridge CFDictionaryRef)auxAttributes,
                                                                            &copyBuffer);
  if (poolStatus != kCVReturnSuccess || NULL == copyBuffer) {
    // Keep the previous (slightly stale) repeat buffer instead of growing the pool.
    return;
  }
  if (noErr == VTPixelTransferSessionTransferImage(self.transferSession, sourceBuffer, copyBuffer)) {
    [self storeRepeatBuffer:copyBuffer];
  }
  CVPixelBufferRelease(copyBuffer);
}

- (void)submitSampleBuffer:(CMSampleBufferRef)sampleBuffer orientation:(uint8_t)orientation
{
  self.samplesInCount += 1;
  if (!self.active) {
    return;
  }

  // Respect this session's framerate even though ReplayKit may deliver faster. The gate is a
  // due-time accumulator rather than a minimum gap from the last accepted frame: gap-based
  // pacing beats against jittery ~30Hz delivery (a frame arriving 1ms early is dropped and the
  // next accepted gap doubles), which measured ~22fps out of a 42fps input. The accumulator
  // admits exactly one frame per interval on average regardless of arrival jitter.
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  uint64_t minIntervalMs = self.fps > 0 ? (uint64_t)(1000 / self.fps) : 0;
  @synchronized (self) {
    if (minIntervalMs > 1) {
      if (nowMs + 1 < self.nextDueMs) {
        self.droppedFpsGateCount += 1;
        return;
      }
      // Re-anchor after stalls so accumulated due time does not admit a burst.
      self.nextDueMs = (self.nextDueMs == 0 || nowMs > self.nextDueMs + minIntervalMs)
        ? nowMs + minIntervalMs
        : self.nextDueMs + minIntervalMs;
    }
    self.acceptedCount += 1;

    // Never block the ReplayKit sample queue. If a frame is already being scaled/submitted,
    // retain only the newest due sample and replace any older pending sample.
    if (self.inFlight) {
      [self replacePendingSampleBuffer:sampleBuffer atTimeMs:nowMs orientation:orientation];
      return;
    }
    self.inFlight = YES;
    self.lastSubmitTimeMs = nowMs;
  }

  CFRetain(sampleBuffer);
  dispatch_async(self.queue, ^{
    [self drainRetainedSampleBuffer:sampleBuffer atTimeMs:nowMs orientation:orientation];
    CFRelease(sampleBuffer);
  });
}

- (void)replacePendingSampleBuffer:(CMSampleBufferRef)sampleBuffer
                           atTimeMs:(uint64_t)nowMs
                        orientation:(uint8_t)orientation
{
  CMSampleBufferRef retainedSampleBuffer = (CMSampleBufferRef)CFRetain(sampleBuffer);
  CMSampleBufferRef previous = _pendingSampleBuffer;
  _pendingSampleBuffer = retainedSampleBuffer;
  self.pendingSubmitTimeMs = nowMs;
  self.pendingOrientation = orientation;
  if (NULL != previous) {
    CFRelease(previous);
    self.droppedReplacedCount += 1;
  }
}

- (nullable CMSampleBufferRef)copyPendingSampleBufferAtTimeMs:(uint64_t *)timeMs
                                                  orientation:(uint8_t *)orientation
{
  @synchronized (self) {
    if (!self.active) {
      [self clearPendingSampleBufferLocked];
      self.inFlight = NO;
      return NULL;
    }
    CMSampleBufferRef pending = _pendingSampleBuffer;
    if (NULL == pending) {
      self.inFlight = NO;
      return NULL;
    }
    _pendingSampleBuffer = NULL;
    *timeMs = self.pendingSubmitTimeMs;
    *orientation = self.pendingOrientation;
    self.lastSubmitTimeMs = self.pendingSubmitTimeMs;
    return pending;
  }
}

- (void)clearPendingSampleBufferLocked
{
  CMSampleBufferRef pending = _pendingSampleBuffer;
  _pendingSampleBuffer = NULL;
  if (NULL != pending) {
    CFRelease(pending);
  }
}

- (void)drainRetainedSampleBuffer:(CMSampleBufferRef)sampleBuffer
                         atTimeMs:(uint64_t)nowMs
                      orientation:(uint8_t)orientation
{
  CMSampleBufferRef currentSampleBuffer = sampleBuffer;
  uint64_t currentTimeMs = nowMs;
  uint8_t currentOrientation = orientation;
  BOOL shouldReleaseCurrentSampleBuffer = NO;

  while (NULL != currentSampleBuffer) {
    [self processRetainedSampleBuffer:currentSampleBuffer
                             atTimeMs:currentTimeMs
                          orientation:currentOrientation];
    if (shouldReleaseCurrentSampleBuffer) {
      CFRelease(currentSampleBuffer);
    }
    currentSampleBuffer = [self copyPendingSampleBufferAtTimeMs:&currentTimeMs
                                                    orientation:&currentOrientation];
    shouldReleaseCurrentSampleBuffer = (NULL != currentSampleBuffer);
  }
}

- (void)processRetainedSampleBuffer:(CMSampleBufferRef)sampleBuffer
                           atTimeMs:(uint64_t)nowMs
                        orientation:(uint8_t)orientation
{
  if (!self.active) {
    return;
  }
  self.currentOrientation = orientation;
  CVPixelBufferRef sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (NULL == sourceBuffer) {
    return;
  }

  if (!self.directSourceEncodingDisabled
      && CVPixelBufferGetWidth(sourceBuffer) == self.width
      && CVPixelBufferGetHeight(sourceBuffer) == self.height) {
    NSError *error;
    if ([self.encoder encodePixelBuffer:sourceBuffer presentationTimeMs:nowMs error:&error]) {
      self.lastEncodeAtMs = nowMs;
      [self refreshRepeatBufferWithCopyOf:sourceBuffer];
      return;
    }
    self.directSourceEncodingDisabled = YES;
    FBExtLogError("Session %u: direct source encode failed; falling back to pixel transfer: %{public}@",
                  self.sessionId,
                  error.description);
  }

  CVPixelBufferRef scaledBuffer = NULL;
  NSDictionary *auxAttributes = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @(POOL_ALLOCATION_THRESHOLD)};
  CVReturn poolStatus = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,
                                                                            self.bufferPool,
                                                                            (__bridge CFDictionaryRef)auxAttributes,
                                                                            &scaledBuffer);
  if (poolStatus != kCVReturnSuccess || NULL == scaledBuffer) {
    // The pool is exhausted (encoder still holds the buffers) - drop the frame instead of growing.
    self.droppedPoolCount += 1;
    return;
  }

  OSStatus transferStatus = VTPixelTransferSessionTransferImage(self.transferSession, sourceBuffer, scaledBuffer);
  if (transferStatus != noErr) {
    FBExtLogError("Session %u: pixel transfer failed (status %d)", self.sessionId, (int)transferStatus);
    CVPixelBufferRelease(scaledBuffer);
    return;
  }

  NSError *error;
  if ([self.encoder encodePixelBuffer:scaledBuffer presentationTimeMs:nowMs error:&error]) {
    self.lastEncodeAtMs = nowMs;
    [self storeRepeatBuffer:scaledBuffer];
  } else {
    FBExtLogError("Session %u: cannot encode a frame: %{public}@", self.sessionId, error.description);
  }
  CVPixelBufferRelease(scaledBuffer);
}

- (void)requestKeyFrame
{
  [self.encoder requestKeyFrame];
}

- (NSDictionary<NSString *, NSNumber *> *)metricsSnapshot
{
  return @{
    @"samplesIn": @(self.samplesInCount),
    @"accepted": @(self.acceptedCount),
    @"encoded": @(self.encodedCount),
    @"droppedFpsGate": @(self.droppedFpsGateCount),
    @"droppedReplaced": @(self.droppedReplacedCount),
    @"droppedPool": @(self.droppedPoolCount),
    @"repeated": @(self.repeatedCount),
    @"encodeLatencyMsLast": @(self.lastEncodeLatencyMs),
    @"encodeLatencyMsAvg": @(round(self.avgEncodeLatencyMs * 10) / 10),
  };
}

- (void)teardown
{
  self.active = NO;
  @synchronized (self) {
    [self clearPendingSampleBufferLocked];
  }
  dispatch_source_t timer = self.repeatTimer;
  if (nil != timer) {
    dispatch_source_cancel(timer);
    self.repeatTimer = nil;
  }
  dispatch_async(self.queue, ^{
    if (NULL != self->_repeatBuffer) {
      CVPixelBufferRelease(self->_repeatBuffer);
      self->_repeatBuffer = NULL;
    }
    if (nil != self.encoder) {
      self.encoder.delegate = nil;
      [self.encoder stop];
      self.encoder = nil;
    }
    [self releaseScalerResources];
  });
}

- (void)releaseScalerResources
{
  if (NULL != self.transferSession) {
    VTPixelTransferSessionInvalidate(self.transferSession);
    CFRelease(self.transferSession);
    self.transferSession = NULL;
  }
  if (NULL != self.bufferPool) {
    CVPixelBufferPoolRelease(self.bufferPool);
    self.bufferPool = NULL;
  }
}

- (void)dealloc
{
  @synchronized (self) {
    [self clearPendingSampleBufferLocked];
  }
  if (nil != _repeatTimer) {
    dispatch_source_cancel(_repeatTimer);
  }
  if (NULL != _repeatBuffer) {
    CVPixelBufferRelease(_repeatBuffer);
    _repeatBuffer = NULL;
  }
  if (nil != _encoder) {
    _encoder.delegate = nil;
    [_encoder stop];
  }
  [self releaseScalerResources];
}

#pragma mark - <FBVideoEncoderDelegate>

- (void)videoEncoder:(FBVideoEncoder *)encoder
       didEncodeFrame:(NSData *)annexBPictureData
           isKeyFrame:(BOOL)isKeyFrame
   presentationTimeUs:(uint64_t)presentationTimeUs
{
  self.encodedCount += 1;
  // The frame pts is the monotonic submit time, so callback-time minus pts is the
  // scale+encode latency.
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  uint64_t submitMs = presentationTimeUs / 1000;
  if (nowMs >= submitMs) {
    uint64_t latencyMs = nowMs - submitMs;
    self.lastEncodeLatencyMs = latencyMs;
    double avg = self.avgEncodeLatencyMs;
    self.avgEncodeLatencyMs = avg <= 0 ? (double)latencyMs : avg * 0.9 + (double)latencyMs * 0.1;
  }

  if (!self.active || annexBPictureData.length == 0) {
    return;
  }
  id<FBExtMessageSink> sink = self.sink;
  if (nil == sink) {
    return;
  }

  // WDA needs the parameter sets before the first IDR that uses them.
  if (isKeyFrame) {
    NSData *parameterSets = encoder.parameterSetAnnexB;
    NSData *lastSent = self.lastSentParameterSets;
    if (parameterSets.length > 0 && (nil == lastSent || ![parameterSets isEqualToData:lastSent])) {
      self.lastSentParameterSets = parameterSets;
      [sink sendProtocolMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeVideoParams,
                                                         self.sessionId,
                                                         parameterSets)
                    isDroppable:NO];
    }
  }

  [sink sendProtocolMessage:FBBroadcastEncodeVideoFrameMessage(self.sessionId,
                                                               presentationTimeUs,
                                                               isKeyFrame,
                                                               self.currentOrientation,
                                                               annexBPictureData)
                isDroppable:!isKeyFrame];
}

@end
