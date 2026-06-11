/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBExtAudioPipeline.h"

#import <AudioToolbox/AudioToolbox.h>

#import "FBBroadcastProtocol.h"
#import "FBExtLogging.h"

static NSString *const FBExtAudioPipelineErrorDomain = @"com.facebook.WebDriverAgent.FBExtAudioPipeline";

static const Float64 FBExtAudioOutputSampleRate = 48000;
/** 960 samples at 48 kHz = one 20 ms Opus packet, the codec's canonical real-time frame size. */
static const UInt32 FBExtAudioFramesPerPacket = 960;
static const NSUInteger FBExtAudioDefaultBitrate = 128000;
static const NSUInteger FBExtAudioDefaultChannels = 2;
/** Pending (retained) ReplayKit buffers beyond this are dropped so a stuck queue cannot grow. */
static const NSUInteger FBExtAudioMaxPendingBuffers = 8;
/** The PCM accumulation ring is bounded to one second of audio (the extension has a ~50MB cap). */
static const UInt32 FBExtAudioMaxRingFrames = 48000;
/** An input pts this far off the expected timeline (broadcast pause) flushes and re-anchors. */
static const int64_t FBExtAudioDiscontinuityUs = 100000;
/** Stage-1 conversion output is drained in chunks of this many frames. */
static const UInt32 FBExtAudioConvertChunkFrames = 4096;

/** Returned by the feeder callbacks when their input is exhausted (any non-zero status stops
    AudioConverterFillComplexBuffer without invalidating the converter). 'wdnd' */
static const OSStatus FBExtAudioNoMoreDataStatus = 0x77646E64;

/** Hands an incoming sample buffer's AudioBufferList to the converter in one piece. */
typedef struct {
  const AudioBufferList *bufferList;
  UInt32 totalFrames;
  BOOL consumed;
} FBExtAudioInputFeed;

/** ReplayKit app audio is stereo at most; leave headroom for unexpected layouts. */
#define FBExtAudioMaxBuffers 8

/** The shape of a copied sample buffer's AudioBufferList — per-buffer sizes and channel
    counts, so the (non-)interleaved layout survives the copy across to the pipeline queue
    (a plain struct so a block can capture it by value). */
typedef struct {
  UInt32 count;
  UInt32 sizes[FBExtAudioMaxBuffers];
  UInt32 channels[FBExtAudioMaxBuffers];
} FBExtAudioBufferLayout;

static OSStatus FBExtAudioFeedInput(AudioConverterRef converter,
                                    UInt32 *ioNumberDataPackets,
                                    AudioBufferList *ioData,
                                    AudioStreamPacketDescription **outDataPacketDescription,
                                    void *inUserData)
{
  FBExtAudioInputFeed *feed = (FBExtAudioInputFeed *)inUserData;
  if (feed->consumed || feed->totalFrames == 0) {
    *ioNumberDataPackets = 0;
    return FBExtAudioNoMoreDataStatus;
  }
  for (UInt32 i = 0; i < feed->bufferList->mNumberBuffers && i < ioData->mNumberBuffers; i++) {
    ioData->mBuffers[i] = feed->bufferList->mBuffers[i];
  }
  ioData->mNumberBuffers = feed->bufferList->mNumberBuffers;
  *ioNumberDataPackets = feed->totalFrames;
  feed->consumed = YES;
  return noErr;
}

/** Hands interleaved canonical PCM from the ring buffer to the Opus encoder. */
typedef struct {
  const uint8_t *bytes;
  UInt32 framesAvailable;
  UInt32 framesUsed;
  UInt32 bytesPerFrame;
  UInt32 channels;
} FBExtAudioRingFeed;

static OSStatus FBExtAudioFeedRing(AudioConverterRef converter,
                                   UInt32 *ioNumberDataPackets,
                                   AudioBufferList *ioData,
                                   AudioStreamPacketDescription **outDataPacketDescription,
                                   void *inUserData)
{
  FBExtAudioRingFeed *feed = (FBExtAudioRingFeed *)inUserData;
  UInt32 remaining = feed->framesAvailable - feed->framesUsed;
  if (remaining == 0) {
    *ioNumberDataPackets = 0;
    return FBExtAudioNoMoreDataStatus;
  }
  UInt32 provide = MIN(*ioNumberDataPackets, remaining);
  ioData->mNumberBuffers = 1;
  ioData->mBuffers[0].mNumberChannels = feed->channels;
  ioData->mBuffers[0].mData = (void *)(feed->bytes + (size_t)feed->framesUsed * feed->bytesPerFrame);
  ioData->mBuffers[0].mDataByteSize = provide * feed->bytesPerFrame;
  feed->framesUsed += provide;
  *ioNumberDataPackets = provide;
  return noErr;
}

@interface FBExtAudioPipeline () {
  AudioConverterRef _inputConverter;
  AudioConverterRef _opusConverter;
  AudioStreamBasicDescription _inputFormat;
  AudioStreamBasicDescription _canonicalFormat;
}

@property (nonatomic, weak) id<FBExtMessageSink> sink;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) NSUInteger channels;
@property (nonatomic) uint16_t preSkip;
@property (nonatomic) UInt32 maxPacketSize;
/** Canonical 48 kHz interleaved PCM awaiting encoding (queue-confined). */
@property (nonatomic) NSMutableData *pcmRing;
/** Scratch buffers reused across conversions (queue-confined). */
@property (nonatomic) NSMutableData *convertScratch;
@property (nonatomic) NSMutableData *packetScratch;
@property (atomic) BOOL active;

// PTS bookkeeping (queue-confined). The output timeline is anchored at the first (or first
// post-discontinuity) input buffer's presentation time and advances 20 ms per emitted packet.
@property (nonatomic) BOOL hasAnchor;
@property (nonatomic) uint64_t nextPacketPtsUs;
@property (nonatomic) int64_t expectedInputPtsUs;
/** The informational input sample rate last advertised in the OpusHead. */
@property (nonatomic) uint32_t opusHeadInputRate;

// Lightweight diagnostics, exposed via metricsSnapshot/the heartbeat. Increments are not
// strictly atomic RMW, which is acceptable for metrics.
@property (atomic) uint64_t samplesInCount;
@property (atomic) uint64_t framesInCount;
@property (atomic) uint64_t droppedQueueFullCount;
@property (atomic) uint64_t packetsEncodedCount;
@property (atomic) uint64_t bytesEncodedCount;
@property (atomic) uint64_t converterRebuildsCount;
@property (atomic) uint64_t encodeErrorsCount;
@property (atomic) uint64_t ringFramesCount;
@property (atomic) NSUInteger pendingBuffers;
/** Failed AudioBufferList extractions, counted separately so their (rate-limited) log can
    report the exact OSStatus — the counter alone proved too opaque to debug a silent stream. */
@property (atomic) uint64_t extractFailuresCount;

@end

@implementation FBExtAudioPipeline

- (nullable instancetype)initWithSessionId:(uint32_t)sessionId
                             configuration:(NSDictionary<NSString *, id> *)configuration
                                      sink:(id<FBExtMessageSink>)sink
                                     error:(NSError **)error
{
  if ((self = [super init])) {
    _sessionId = sessionId;
    _sink = sink;
    _queue = dispatch_queue_create([NSString stringWithFormat:@"wda.broadcast.audio.%u", sessionId].UTF8String,
                                   DISPATCH_QUEUE_SERIAL);

    NSUInteger channels = [configuration[FBBroadcastKeyChannels] unsignedIntegerValue];
    if (channels != 1 && channels != 2) {
      channels = FBExtAudioDefaultChannels;
    }
    NSUInteger bitrate = [configuration[FBBroadcastKeyBitrate] unsignedIntegerValue];
    if (bitrate == 0) {
      bitrate = FBExtAudioDefaultBitrate;
    }
    _channels = channels;

    _canonicalFormat = (AudioStreamBasicDescription){0};
    _canonicalFormat.mSampleRate = FBExtAudioOutputSampleRate;
    _canonicalFormat.mFormatID = kAudioFormatLinearPCM;
    _canonicalFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    _canonicalFormat.mChannelsPerFrame = (UInt32)channels;
    _canonicalFormat.mBitsPerChannel = 32;
    _canonicalFormat.mBytesPerFrame = (UInt32)channels * sizeof(float);
    _canonicalFormat.mFramesPerPacket = 1;
    _canonicalFormat.mBytesPerPacket = _canonicalFormat.mBytesPerFrame;

    AudioStreamBasicDescription opusFormat = {0};
    opusFormat.mSampleRate = FBExtAudioOutputSampleRate;
    opusFormat.mFormatID = kAudioFormatOpus;
    opusFormat.mChannelsPerFrame = (UInt32)channels;
    opusFormat.mFramesPerPacket = FBExtAudioFramesPerPacket;

    // Created up front so an unavailable Opus encoder fails the SESSION_ADD immediately
    // (surfaced as SESSION_ERROR) instead of silently producing no packets.
    OSStatus status = AudioConverterNew(&_canonicalFormat, &opusFormat, &_opusConverter);
    if (status != noErr || NULL == _opusConverter) {
      if (error) {
        *error = [NSError errorWithDomain:FBExtAudioPipelineErrorDomain
                                     code:status
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create the Opus encoder (status %d)", (int)status]}];
      }
      return nil;
    }
    UInt32 bitrateValue = (UInt32)bitrate;
    AudioConverterSetProperty(_opusConverter, kAudioConverterEncodeBitRate,
                              sizeof(bitrateValue), &bitrateValue);

    AudioConverterPrimeInfo primeInfo = {0};
    UInt32 size = sizeof(primeInfo);
    if (noErr == AudioConverterGetProperty(_opusConverter, kAudioConverterPrimeInfo, &size, &primeInfo)) {
      _preSkip = (uint16_t)MIN(primeInfo.leadingFrames, (UInt32)UINT16_MAX);
    }
    UInt32 maxPacketSize = 0;
    size = sizeof(maxPacketSize);
    if (noErr != AudioConverterGetProperty(_opusConverter, kAudioConverterPropertyMaximumOutputPacketSize,
                                           &size, &maxPacketSize) || maxPacketSize == 0) {
      maxPacketSize = 1500;
    }
    _maxPacketSize = maxPacketSize;

    _pcmRing = [NSMutableData data];
    _convertScratch = [NSMutableData dataWithLength:FBExtAudioConvertChunkFrames * _canonicalFormat.mBytesPerFrame];
    _packetScratch = [NSMutableData dataWithLength:maxPacketSize];
    _active = YES;

    // The real input rate is unknown until the first buffer arrives; the OpusHead is re-sent
    // if it turns out to differ (the field is informational metadata for consumers).
    _opusHeadInputRate = (uint32_t)FBExtAudioOutputSampleRate;
    [self sendOpusHead];
  }
  return self;
}

- (void)dealloc
{
  [self disposeConvertersLocked];
}

- (void)teardown
{
  self.active = NO;
  dispatch_async(self.queue, ^{
    [self disposeConvertersLocked];
    self.pcmRing.length = 0;
    self.ringFramesCount = 0;
  });
}

- (void)disposeConvertersLocked
{
  if (NULL != _inputConverter) {
    AudioConverterDispose(_inputConverter);
    _inputConverter = NULL;
  }
  if (NULL != _opusConverter) {
    AudioConverterDispose(_opusConverter);
    _opusConverter = NULL;
  }
}

- (void)sendOpusHead
{
  NSData *opusHead = FBBroadcastCreateOpusHead((uint8_t)self.channels, self.preSkip, self.opusHeadInputRate);
  [self.sink sendProtocolMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeAudioParams,
                                                          self.sessionId,
                                                          opusHead)
                     isDroppable:NO];
}

#pragma mark - Sample intake

- (void)submitAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  if (!self.active) {
    return;
  }
  self.samplesInCount += 1;
  if (self.pendingBuffers >= FBExtAudioMaxPendingBuffers) {
    self.droppedQueueFullCount += 1;
    return;
  }

  // The PCM is extracted and copied HERE, synchronously on the ReplayKit callback, by reading
  // the sample buffer's CMBlockBuffer directly. The obvious API —
  // CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer — fails outright on replayd's
  // app-audio buffers (kCMSampleBufferError_ArrayTooSmall even with an 8-buffer list for this
  // single-buffer interleaved format: its no-copy path cannot represent their block-buffer
  // layout), so the buffer-list shape is rebuilt from the format description instead and
  // CMBlockBufferCopyDataBytes does the read — it handles non-contiguous block buffers.
  // Copying on the callback also keeps us clear of replayd reusing the buffer's backing
  // memory after the callback returns; only the copied bytes cross to the queue.
  CMAudioFormatDescriptionRef formatDescription =
    (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *asbdPtr = NULL == formatDescription
    ? NULL
    : CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
  CMItemCount frameCount = CMSampleBufferGetNumSamples(sampleBuffer);
  if (NULL == asbdPtr || frameCount <= 0) {
    return;
  }
  AudioStreamBasicDescription asbd = *asbdPtr;

  CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
  if (NULL == dataBuffer || asbd.mBytesPerFrame == 0) {
    self.encodeErrorsCount += 1;
    [self logExtractFailure:kCMSampleBufferError_RequiredParameterMissing format:&asbd frameCount:frameCount];
    return;
  }

  // Non-interleaved LPCM lays the planes out back-to-back in the block buffer, one per
  // channel (the ASBD's mBytesPerFrame then describes a single plane); interleaved audio —
  // what ReplayKit actually delivers — is one buffer. Derive the frame count from the bytes
  // actually present so a short buffer can never make the converter read past the copy.
  BOOL nonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
  UInt32 planes = nonInterleaved ? MAX(asbd.mChannelsPerFrame, 1u) : 1;
  size_t dataLength = CMBlockBufferGetDataLength(dataBuffer);
  size_t planeStride = dataLength / planes;
  CMItemCount framesInData = (CMItemCount)(planeStride / asbd.mBytesPerFrame);
  frameCount = MIN(frameCount, framesInData);
  if (planes > FBExtAudioMaxBuffers || frameCount <= 0) {
    self.encodeErrorsCount += 1;
    [self logExtractFailure:kCMSampleBufferError_InvalidMediaFormat format:&asbd frameCount:frameCount];
    return;
  }
  size_t planeBytes = (size_t)frameCount * asbd.mBytesPerFrame;

  FBExtAudioBufferLayout layout = {0};
  layout.count = planes;
  NSMutableData *pcm = [NSMutableData dataWithLength:planes * planeBytes];
  uint8_t *dst = pcm.mutableBytes;
  for (UInt32 i = 0; i < planes; i++) {
    layout.sizes[i] = (UInt32)planeBytes;
    layout.channels[i] = nonInterleaved ? 1 : asbd.mChannelsPerFrame;
    OSStatus status = CMBlockBufferCopyDataBytes(dataBuffer, i * planeStride, planeBytes, dst + i * planeBytes);
    if (status != noErr) {
      self.encodeErrorsCount += 1;
      [self logExtractFailure:status format:&asbd frameCount:frameCount];
      return;
    }
  }

  CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  BOOL ptsValid = CMTIME_IS_NUMERIC(pts);
  int64_t ptsUs = ptsValid ? (int64_t)(CMTimeGetSeconds(pts) * 1000000.0) : 0;

  self.pendingBuffers += 1;
  dispatch_async(self.queue, ^{
    self.pendingBuffers -= 1;
    if (self.active) {
      [self processCopiedPCM:pcm layout:layout format:asbd frameCount:frameCount ptsUs:ptsUs ptsValid:ptsValid];
    }
  });
}

/** Logs a failed AudioBufferList extraction with its OSStatus and input format — the first few
    and then a trickle, so a per-buffer failure mode (~50/s) cannot flood the log. */
- (void)logExtractFailure:(OSStatus)status
                   format:(const AudioStreamBasicDescription *)asbd
               frameCount:(CMItemCount)frameCount
{
  uint64_t failures = self.extractFailuresCount + 1;
  self.extractFailuresCount = failures;
  if (failures > 5 && 0 != failures % 1000) {
    return;
  }
  uint32_t formatID = (uint32_t)asbd->mFormatID;
  FBExtLogError("Audio session %u: cannot extract the sample buffer's audio (failure %llu, status %d, fmt '%c%c%c%c', flags 0x%x, rate %.0f, %u ch, %u bit, %ld frames)",
                self.sessionId, (unsigned long long)failures, (int)status,
                (char)(formatID >> 24), (char)(formatID >> 16), (char)(formatID >> 8), (char)formatID,
                (unsigned)asbd->mFormatFlags, asbd->mSampleRate,
                (unsigned)asbd->mChannelsPerFrame, (unsigned)asbd->mBitsPerChannel, (long)frameCount);
}

- (void)processCopiedPCM:(NSData *)pcm
                  layout:(FBExtAudioBufferLayout)layout
                  format:(AudioStreamBasicDescription)asbd
              frameCount:(CMItemCount)frameCount
                   ptsUs:(int64_t)ptsUs
                ptsValid:(BOOL)ptsValid
{
  if (layout.count == 0 || pcm.length == 0) {
    return;
  }
  if (![self ensureInputConverterForFormat:&asbd]) {
    return;
  }

  [self reanchorIfNeededForPtsUs:ptsUs valid:ptsValid frameCount:frameCount sampleRate:asbd.mSampleRate];
  self.framesInCount += (uint64_t)frameCount;

  // Rebuild the original (non-)interleaved AudioBufferList over the contiguous copy; pcm
  // outlives the conversion, so the pointers stay valid for the converter feed.
  struct {
    AudioBufferList list;
    AudioBuffer extra[FBExtAudioMaxBuffers - 1];
  } bufferListStorage;
  bufferListStorage.list.mNumberBuffers = layout.count;
  const uint8_t *base = pcm.bytes;
  size_t offset = 0;
  for (UInt32 i = 0; i < layout.count; i++) {
    AudioBuffer *buffer = &bufferListStorage.list.mBuffers[i];
    buffer->mNumberChannels = layout.channels[i];
    buffer->mDataByteSize = layout.sizes[i];
    buffer->mData = (void *)(base + offset);
    offset += layout.sizes[i];
  }

  [self convertToRing:&bufferListStorage.list frameCount:(UInt32)frameCount];
  [self encodePendingPackets];
}

#pragma mark - Timeline

- (void)reanchorIfNeededForPtsUs:(int64_t)ptsUs
                           valid:(BOOL)valid
                      frameCount:(CMItemCount)frameCount
                      sampleRate:(Float64)sampleRate
{
  if (!valid || sampleRate <= 0) {
    return;
  }
  if (self.hasAnchor && llabs(ptsUs - self.expectedInputPtsUs) <= FBExtAudioDiscontinuityUs) {
    self.expectedInputPtsUs += (int64_t)((double)frameCount / sampleRate * 1000000.0);
    return;
  }
  if (self.hasAnchor) {
    // A gap (e.g. a paused broadcast): drop buffered samples so old audio is not replayed
    // against fresh timestamps.
    self.pcmRing.length = 0;
    self.ringFramesCount = 0;
  }
  self.hasAnchor = YES;
  self.nextPacketPtsUs = ptsUs > 0 ? (uint64_t)ptsUs : 0;
  self.expectedInputPtsUs = ptsUs + (int64_t)((double)frameCount / sampleRate * 1000000.0);
}

#pragma mark - Conversion

- (BOOL)ensureInputConverterForFormat:(const AudioStreamBasicDescription *)asbd
{
  if (NULL != _inputConverter && 0 == memcmp(asbd, &_inputFormat, sizeof(_inputFormat))) {
    return YES;
  }
  if (NULL != _inputConverter) {
    AudioConverterDispose(_inputConverter);
    _inputConverter = NULL;
    self.converterRebuildsCount += 1;
  }
  OSStatus status = AudioConverterNew(asbd, &_canonicalFormat, &_inputConverter);
  if (status != noErr || NULL == _inputConverter) {
    _inputConverter = NULL;
    self.encodeErrorsCount += 1;
    FBExtLogError("Audio session %u: cannot create the input converter (status %d, rate %.0f, %u ch)",
                  self.sessionId, (int)status, asbd->mSampleRate, (unsigned)asbd->mChannelsPerFrame);
    return NO;
  }
  _inputFormat = *asbd;
  uint32_t inputRate = (uint32_t)asbd->mSampleRate;
  if (inputRate > 0 && inputRate != self.opusHeadInputRate) {
    self.opusHeadInputRate = inputRate;
    [self sendOpusHead];
  }
  return YES;
}

- (void)convertToRing:(const AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
  FBExtAudioInputFeed feed = { bufferList, frameCount, NO };
  for (;;) {
    UInt32 outFrames = FBExtAudioConvertChunkFrames;
    AudioBufferList outList = {0};
    outList.mNumberBuffers = 1;
    outList.mBuffers[0].mNumberChannels = _canonicalFormat.mChannelsPerFrame;
    outList.mBuffers[0].mData = self.convertScratch.mutableBytes;
    outList.mBuffers[0].mDataByteSize = (UInt32)self.convertScratch.length;
    OSStatus status = AudioConverterFillComplexBuffer(_inputConverter, FBExtAudioFeedInput, &feed,
                                                      &outFrames, &outList, NULL);
    if (outFrames > 0) {
      [self.pcmRing appendBytes:self.convertScratch.bytes
                         length:(NSUInteger)outFrames * _canonicalFormat.mBytesPerFrame];
    }
    if (status == FBExtAudioNoMoreDataStatus || outFrames == 0) {
      break;
    }
    if (status != noErr) {
      self.encodeErrorsCount += 1;
      FBExtLogError("Audio session %u: PCM conversion failed (status %d)", self.sessionId, (int)status);
      break;
    }
  }

  // Bound the ring: drop the oldest samples and keep the packet timeline aligned with the
  // ones that remain.
  UInt32 ringFrames = (UInt32)(self.pcmRing.length / _canonicalFormat.mBytesPerFrame);
  if (ringFrames > FBExtAudioMaxRingFrames) {
    UInt32 dropFrames = ringFrames - FBExtAudioMaxRingFrames;
    [self.pcmRing replaceBytesInRange:NSMakeRange(0, (NSUInteger)dropFrames * _canonicalFormat.mBytesPerFrame)
                            withBytes:NULL
                               length:0];
    self.nextPacketPtsUs += (uint64_t)((double)dropFrames / FBExtAudioOutputSampleRate * 1000000.0);
    ringFrames = FBExtAudioMaxRingFrames;
  }
  self.ringFramesCount = ringFrames;
}

- (void)encodePendingPackets
{
  if (NULL == _opusConverter) {
    return;
  }
  while (self.pcmRing.length / _canonicalFormat.mBytesPerFrame >= FBExtAudioFramesPerPacket) {
    FBExtAudioRingFeed feed = {
      (const uint8_t *)self.pcmRing.bytes,
      (UInt32)(self.pcmRing.length / _canonicalFormat.mBytesPerFrame),
      0,
      _canonicalFormat.mBytesPerFrame,
      _canonicalFormat.mChannelsPerFrame,
    };
    BOOL producedPacket = NO;
    for (;;) {
      AudioBufferList outList = {0};
      outList.mNumberBuffers = 1;
      outList.mBuffers[0].mNumberChannels = _canonicalFormat.mChannelsPerFrame;
      outList.mBuffers[0].mData = self.packetScratch.mutableBytes;
      outList.mBuffers[0].mDataByteSize = (UInt32)self.packetScratch.length;
      AudioStreamPacketDescription packetDescription = {0};
      UInt32 packetCount = 1;
      OSStatus status = AudioConverterFillComplexBuffer(_opusConverter, FBExtAudioFeedRing, &feed,
                                                        &packetCount, &outList, &packetDescription);
      if (packetCount > 0) {
        UInt32 packetBytes = packetDescription.mDataByteSize > 0
          ? packetDescription.mDataByteSize
          : outList.mBuffers[0].mDataByteSize;
        [self emitOpusPacketWithBytes:self.packetScratch.bytes length:packetBytes];
        producedPacket = YES;
      }
      if (status == FBExtAudioNoMoreDataStatus || packetCount == 0) {
        break;
      }
      if (status != noErr) {
        self.encodeErrorsCount += 1;
        FBExtLogError("Audio session %u: Opus encoding failed (status %d)", self.sessionId, (int)status);
        break;
      }
    }
    // Frames handed to the encoder are gone from the ring even when no packet came out yet
    // (the converter buffers them internally).
    if (feed.framesUsed > 0) {
      [self.pcmRing replaceBytesInRange:NSMakeRange(0, (NSUInteger)feed.framesUsed * _canonicalFormat.mBytesPerFrame)
                              withBytes:NULL
                                 length:0];
    }
    self.ringFramesCount = self.pcmRing.length / _canonicalFormat.mBytesPerFrame;
    if (!producedPacket) {
      break;
    }
  }
}

- (void)emitOpusPacketWithBytes:(const void *)bytes length:(UInt32)length
{
  if (length == 0) {
    return;
  }
  NSData *packet = [NSData dataWithBytes:bytes length:length];
  uint64_t ptsUs = self.nextPacketPtsUs;
  self.nextPacketPtsUs += (uint64_t)((double)FBExtAudioFramesPerPacket / FBExtAudioOutputSampleRate * 1000000.0);
  self.packetsEncodedCount += 1;
  self.bytesEncodedCount += length;
  [self.sink sendProtocolMessage:FBBroadcastEncodeAudioFrameMessage(self.sessionId, ptsUs, packet)
                     isDroppable:YES];
}

#pragma mark - Metrics

- (NSDictionary<NSString *, NSNumber *> *)metricsSnapshot
{
  return @{
    @"samplesIn": @(self.samplesInCount),
    @"framesIn": @(self.framesInCount),
    @"droppedQueueFull": @(self.droppedQueueFullCount),
    @"packetsEncoded": @(self.packetsEncodedCount),
    @"bytesEncoded": @(self.bytesEncodedCount),
    @"converterRebuilds": @(self.converterRebuildsCount),
    @"encodeErrors": @(self.encodeErrorsCount),
    @"extractFailures": @(self.extractFailuresCount),
    @"ringFrames": @(self.ringFramesCount),
  };
}

@end
