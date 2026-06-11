/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/** Receives fully framed protocol messages produced by a pipeline. */
@protocol FBExtMessageSink <NSObject>

/**
 @param message A complete wire message (header + payload)
 @param droppable YES when the message may be dropped under backpressure (delta frames)
 */
- (void)sendProtocolMessage:(NSData *)message isDroppable:(BOOL)droppable;

@end

/**
 One per WDA capture session: letterbox-scales incoming ReplayKit pixel buffers to the session's
 dimensions and encodes them with the session's codec/bitrate/fps, emitting VIDEO_PARAMS and
 VIDEO_FRAME protocol messages to the sink.
 */
@interface FBExtSessionPipeline : NSObject

@property (nonatomic, readonly) uint32_t sessionId;

/**
 @param sessionId The WDA session identifier
 @param configuration The SESSION_ADD JSON payload (width, height, codec, bitrate, fps)
 @param sink The message sink (held weakly)
 @param error Set when the encoder or scaler cannot be created
 */
- (nullable instancetype)initWithSessionId:(uint32_t)sessionId
                             configuration:(NSDictionary<NSString *, id> *)configuration
                                      sink:(id<FBExtMessageSink>)sink
                                     error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;

/**
 Submits a ReplayKit video sample for this session. Called on the ReplayKit sample queue and
 never blocks: the frame is dropped when the session is not yet due for a new frame (fps pacing)
 or when the previous frame is still being scaled/submitted.

 @param sampleBuffer The video sample from ReplayKit
 @param orientation The CGImagePropertyOrientation (1-8) reported for the sample
 */
- (void)submitSampleBuffer:(CMSampleBufferRef)sampleBuffer orientation:(uint8_t)orientation;

/** Forces the next encoded frame to be a key frame. */
- (void)requestKeyFrame;

/**
 A point-in-time snapshot of this pipeline's counters, safe to call from any thread:
 samplesIn (frames offered by ReplayKit), accepted (passed the fps gate), encoded (encoder
 callbacks), droppedFpsGate, droppedReplaced (latched frame superseded before processing),
 droppedPool (scaled-buffer pool exhausted), repeated (last frame re-encoded to fill a
 delivery gap), encodeLatencyMsLast/encodeLatencyMsAvg (submit-to-encoder-callback time).
 */
- (NSDictionary<NSString *, NSNumber *> *)metricsSnapshot;

/** Stops the encoder and releases the scaler and buffer pool. */
- (void)teardown;

@end

NS_ASSUME_NONNULL_END
