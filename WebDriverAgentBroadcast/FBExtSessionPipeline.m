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
static const int POOL_ALLOCATION_THRESHOLD = 3;

@interface FBExtSessionPipeline () <FBVideoEncoderDelegate>

@property (nonatomic, weak) id<FBExtMessageSink> sink;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, nullable) FBVideoEncoder *encoder;
@property (nonatomic) VTPixelTransferSessionRef transferSession;
@property (nonatomic) CVPixelBufferPoolRef bufferPool;
@property (nonatomic) NSUInteger fps;
@property (atomic) uint64_t lastSubmitTimeMs;
@property (atomic) BOOL inFlight;
@property (atomic) BOOL active;
@property (atomic) uint8_t currentOrientation;
@property (nonatomic, nullable, copy) NSData *lastSentParameterSets;

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

    NSDictionary *pixelBufferAttributes = @{
      (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
      (id)kCVPixelBufferWidthKey: @(width),
      (id)kCVPixelBufferHeightKey: @(height),
      (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    NSDictionary *poolAttributes = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @1};
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
  }
  return self;
}

- (void)submitSampleBuffer:(CMSampleBufferRef)sampleBuffer orientation:(uint8_t)orientation
{
  if (!self.active) {
    return;
  }
  self.currentOrientation = orientation;

  // Respect this session's framerate even though ReplayKit may deliver faster.
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  uint64_t minIntervalMs = self.fps > 0 ? (uint64_t)(1000 / self.fps) : 0;
  if (minIntervalMs > 1 && nowMs - self.lastSubmitTimeMs < minIntervalMs - 1) {
    return;
  }
  // Never queue and never block the ReplayKit sample queue: drop when the previous frame is
  // still being scaled/submitted.
  if (self.inFlight) {
    return;
  }
  self.inFlight = YES;
  self.lastSubmitTimeMs = nowMs;

  CFRetain(sampleBuffer);
  dispatch_async(self.queue, ^{
    [self processRetainedSampleBuffer:sampleBuffer atTimeMs:nowMs];
    CFRelease(sampleBuffer);
    self.inFlight = NO;
  });
}

- (void)processRetainedSampleBuffer:(CMSampleBufferRef)sampleBuffer atTimeMs:(uint64_t)nowMs
{
  if (!self.active) {
    return;
  }
  CVPixelBufferRef sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (NULL == sourceBuffer) {
    return;
  }

  CVPixelBufferRef scaledBuffer = NULL;
  NSDictionary *auxAttributes = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @(POOL_ALLOCATION_THRESHOLD)};
  CVReturn poolStatus = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,
                                                                            self.bufferPool,
                                                                            (__bridge CFDictionaryRef)auxAttributes,
                                                                            &scaledBuffer);
  if (poolStatus != kCVReturnSuccess || NULL == scaledBuffer) {
    // The pool is exhausted (encoder still holds the buffers) - drop the frame instead of growing.
    return;
  }

  OSStatus transferStatus = VTPixelTransferSessionTransferImage(self.transferSession, sourceBuffer, scaledBuffer);
  if (transferStatus != noErr) {
    FBExtLogError("Session %u: pixel transfer failed (status %d)", self.sessionId, (int)transferStatus);
    CVPixelBufferRelease(scaledBuffer);
    return;
  }

  NSError *error;
  if (![self.encoder encodePixelBuffer:scaledBuffer presentationTimeMs:nowMs error:&error]) {
    FBExtLogError("Session %u: cannot encode a frame: %{public}@", self.sessionId, error.description);
  }
  CVPixelBufferRelease(scaledBuffer);
}

- (void)requestKeyFrame
{
  [self.encoder requestKeyFrame];
}

- (void)teardown
{
  self.active = NO;
  dispatch_async(self.queue, ^{
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

  NSData *payload = FBBroadcastEncodeVideoFramePayload(presentationTimeUs,
                                                       isKeyFrame,
                                                       self.currentOrientation,
                                                       annexBPictureData);
  [sink sendProtocolMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeVideoFrame, self.sessionId, payload)
                isDroppable:!isKeyFrame];
}

@end
