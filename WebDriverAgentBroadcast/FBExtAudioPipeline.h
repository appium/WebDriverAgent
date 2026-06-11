/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#import "FBExtSessionPipeline.h"

NS_ASSUME_NONNULL_BEGIN

/**
 One per WDA audio capture session: converts incoming ReplayKit app-audio samples to
 48 kHz PCM, encodes them into 20 ms (960-sample) Opus packets with AudioToolbox's
 AudioConverter and emits AUDIO_PARAMS (OpusHead) and AUDIO_FRAME protocol messages
 to the sink.
 */
@interface FBExtAudioPipeline : NSObject

/** The wire session id (FBBroadcastAudioSessionIdFlag set). */
@property (nonatomic, readonly) uint32_t sessionId;

/**
 @param sessionId The wire session identifier
 @param configuration The SESSION_ADD JSON payload (media, codec, bitrate, channels, sampleRate)
 @param sink The message sink (held weakly)
 @param error Set when the Opus encoder cannot be created
 */
- (nullable instancetype)initWithSessionId:(uint32_t)sessionId
                             configuration:(NSDictionary<NSString *, id> *)configuration
                                      sink:(id<FBExtMessageSink>)sink
                                     error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;

/**
 Submits a ReplayKit app-audio sample for this session. Called on the ReplayKit sample queue
 and never blocks: the buffer is retained and processed asynchronously, and dropped when too
 many buffers are already pending.
 */
- (void)submitAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 A point-in-time snapshot of this pipeline's counters, safe to call from any thread:
 samplesIn (buffers offered by ReplayKit), framesIn (PCM frames extracted), droppedQueueFull,
 packetsEncoded, bytesEncoded, converterRebuilds (input format changes), encodeErrors,
 ringFrames (48 kHz frames currently buffered).
 */
- (NSDictionary<NSString *, NSNumber *> *)metricsSnapshot;

/** Stops processing and releases both converters. */
- (void)teardown;

@end

NS_ASSUME_NONNULL_END
