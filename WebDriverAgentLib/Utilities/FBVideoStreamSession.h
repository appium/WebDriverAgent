/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "FBVideoEncoder.h"

NS_ASSUME_NONNULL_BEGIN

/** Describes a single screen-capture streaming request. */
@interface FBScreenCaptureConfiguration : NSObject

/** The video codec to encode with. */
@property (nonatomic) FBVideoCodec codec;
/** The encoded frame width in pixels. */
@property (nonatomic) NSUInteger width;
/** The encoded frame height in pixels. */
@property (nonatomic) NSUInteger height;
/** The target average bitrate in bits per second. */
@property (nonatomic) NSUInteger bitrate;
/** The capture/encode framerate in frames per second. */
@property (nonatomic) NSUInteger fps;
/** The TCP port the raw Annex-B stream is broadcast on. */
@property (nonatomic) uint16_t port;

@end

/**
 A single, independently controllable screen-capture stream: one encoder, one TCP broadcaster
 and its own set of clients, identified by a numeric id. Sessions are driven by a shared capture
 loop (see FBVideoStreamManager) that grabs and decodes each screen frame once and fans it out to
 every active session, so multiple codecs/resolutions can be produced from a single capture.
 */
@interface FBVideoStreamSession : NSObject

/** The session identifier assigned by the manager. */
@property (nonatomic, readonly) NSUInteger identifier;
/** The configuration this session was started with. */
@property (nonatomic, readonly) FBScreenCaptureConfiguration *configuration;

- (instancetype)initWithIdentifier:(NSUInteger)identifier
                     configuration:(FBScreenCaptureConfiguration *)configuration;

- (instancetype)init NS_UNAVAILABLE;

/**
 Binds the broadcast socket and creates the encoder.

 @param error If there is an error, upon return contains an NSError describing the problem
 @return NO in case of a failure (e.g. the port is in use or the encoder cannot be created)
 */
- (BOOL)startWithError:(NSError **)error;

/** Tears the session down and disconnects its clients. */
- (void)stop;

/** YES if at least one client is currently connected to this session. */
- (BOOL)hasClients;

/** Forces the encoder to emit a key frame as soon as possible. */
- (void)requestKeyFrame;

/**
 Encodes the given (already decoded) screen image if this session has clients and is due for a
 new frame according to its configured framerate. The image is shared across sessions, so this
 method must not mutate it.

 @param image The decoded screen image
 @param nowMs A monotonic timestamp in milliseconds
 */
- (void)maybeEncodeCGImage:(CGImageRef)image atTimeMs:(uint64_t)nowMs;

/** @return A dictionary describing this session. */
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
