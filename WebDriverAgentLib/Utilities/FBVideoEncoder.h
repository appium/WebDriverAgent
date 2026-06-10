/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/** The hardware video codec used for encoding. */
typedef NS_ENUM(NSUInteger, FBVideoCodec) {
  FBVideoCodecH264,
  FBVideoCodecH265,
};

@class FBVideoEncoder;

@protocol FBVideoEncoderDelegate <NSObject>

/**
 Called whenever the encoder produces an encoded picture.

 The data is a sequence of picture (VCL) NAL units in Annex-B format (each prefixed with a
 00 00 00 01 start code). Parameter sets (SPS/PPS, plus VPS for HEVC) are NOT prepended here;
 the most recent ones are available via parameterSetAnnexB so the consumer can place them
 according to its own wire format.

 @param encoder The encoder that produced the picture
 @param annexBPictureData The encoded picture in Annex-B format (VCL NAL units only)
 @param isKeyFrame YES if the picture is a key (IDR) frame
 @param presentationTimeUs The frame presentation timestamp in microseconds
 */
- (void)videoEncoder:(FBVideoEncoder *)encoder
       didEncodeFrame:(NSData *)annexBPictureData
           isKeyFrame:(BOOL)isKeyFrame
   presentationTimeUs:(uint64_t)presentationTimeUs;

@end

/**
 A thin wrapper around a VTCompressionSession that encodes 32BGRA pixel buffers into an
 H.264 or H.265 Annex-B elementary stream. Designed to be driven by a single capture loop,
 but multiple encoders may run concurrently against the same frame source.
 */
@interface FBVideoEncoder : NSObject

@property (nonatomic, weak, nullable) id<FBVideoEncoderDelegate> delegate;
@property (nonatomic, readonly) FBVideoCodec codec;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) NSUInteger bitrate;
@property (nonatomic, readonly) NSUInteger fps;

/**
 The most recently produced parameter sets (SPS/PPS, plus VPS for HEVC) in Annex-B form,
 or nil before the first key frame has been produced. This blob can be sent to a newly
 connected client so that it can start decoding from the next key frame.
 */
@property (atomic, copy, readonly, nullable) NSData *parameterSetAnnexB;

/**
 Creates and starts a compression session for the given parameters.

 @param codec The video codec to use
 @param width The encoded frame width in pixels (should be even)
 @param height The encoded frame height in pixels (should be even)
 @param bitrate The target average bitrate in bits per second
 @param fps The expected number of frames per second
 @param error If there is an error, upon return contains an NSError describing the problem
 @return A configured encoder instance or nil in case of a failure
 */
- (nullable instancetype)initWithCodec:(FBVideoCodec)codec
                                 width:(NSUInteger)width
                                height:(NSUInteger)height
                               bitrate:(NSUInteger)bitrate
                                   fps:(NSUInteger)fps
                                 error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;

/**
 Submits a pixel buffer for encoding. Encoded frames are delivered asynchronously to the delegate.

 @param pixelBuffer The 32BGRA pixel buffer to encode
 @param presentationTimeMs A monotonically increasing timestamp in milliseconds
 @param error If there is an error, upon return contains an NSError describing the problem
 @return NO if the frame could not be submitted
 */
- (BOOL)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer
        presentationTimeMs:(uint64_t)presentationTimeMs
                     error:(NSError **)error;

/**
 Forces the next submitted frame to be encoded as a key frame. Useful to let a newly
 connected client start decoding without waiting for the next periodic key frame.
 */
- (void)requestKeyFrame;

/** Flushes pending frames and tears the compression session down. */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
