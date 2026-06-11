/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** The framing used for the broadcast byte stream. */
typedef NS_ENUM(NSUInteger, FBAudioFraming) {
  /** Bare Opus packets written back-to-back (default). Not self-delimiting. */
  FBAudioFramingRaw,
  /** scrcpy packet framing: each Opus packet wrapped as [8B pts+flags][4B size][packet]. */
  FBAudioFramingScrcpy,
};

/** Describes a single audio-capture streaming request. */
@interface FBAudioCaptureConfiguration : NSObject

/** The target average bitrate in bits per second. */
@property (nonatomic) NSUInteger bitrate;
/** The encoded channel count (1 or 2). */
@property (nonatomic) NSUInteger channels;
/** The framing of the broadcast byte stream (raw Opus packets by default). */
@property (nonatomic) FBAudioFraming framing;
/** The TCP port the encoded stream is broadcast on. */
@property (nonatomic) uint16_t port;

@end

/**
 A single, independently controllable audio-capture stream: one TCP broadcaster and its own set
 of clients, identified by a numeric id. Unlike video sessions there is no local fallback
 source - encoded Opus packets only arrive from the ReplayKit broadcast extension, so the
 session streams nothing until a broadcast is active.
 */
@interface FBAudioStreamSession : NSObject

/** The session identifier assigned by the manager. */
@property (nonatomic, readonly) NSUInteger identifier;
/** The configuration this session was started with. */
@property (nonatomic, readonly) FBAudioCaptureConfiguration *configuration;

- (instancetype)initWithIdentifier:(NSUInteger)identifier
                     configuration:(FBAudioCaptureConfiguration *)configuration;

- (instancetype)init NS_UNAVAILABLE;

/**
 Binds the broadcast socket.

 @param error If there is an error, upon return contains an NSError describing the problem
 @return NO in case of a failure (e.g. the port is in use)
 */
- (BOOL)startWithError:(NSError **)error;

/** Tears the session down and disconnects its clients. */
- (void)stop;

/** YES if at least one client is currently connected to this session. */
- (BOOL)hasClients;

/**
 Stores a fresh OpusHead received from the broadcast extension. In scrcpy framing a config
 packet is re-broadcast when the header changed.
 */
- (void)ingestBroadcastOpusHead:(NSData *)opusHead;

/** Broadcasts one encoded Opus packet received from the broadcast extension. */
- (void)ingestBroadcastPacket:(NSData *)opusPacket ptsUs:(uint64_t)ptsUs;

/** Marks the broadcast source as gone (the extension disconnected); the session stays alive. */
- (void)detachBroadcastSource;

/** Records an extension-side failure for this session (shown in the status dictionary). */
- (void)markBroadcastError:(NSString *)message;

/** @return A dictionary describing this session. */
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
