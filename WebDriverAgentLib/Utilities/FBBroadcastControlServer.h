/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBBroadcastProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Callbacks are invoked on the server's internal serial queue.
 */
@protocol FBBroadcastControlServerDelegate <NSObject>

/** The extension connected and sent its HELLO message. */
- (void)broadcastServerDidConnect:(NSDictionary<NSString *, id> *)helloInfo;

/** A periodic heartbeat with the extension's stats. */
- (void)broadcastServerDidReceiveHeartbeat:(NSDictionary<NSString *, id> *)heartbeat;

/** A broadcast lifecycle event (paused/resumed/finishing). */
- (void)broadcastServerDidReceiveStatus:(NSDictionary<NSString *, id> *)status;

/** The extension could not serve the given session (e.g. its encoder failed). */
- (void)broadcastServerDidReceiveSessionError:(NSString *)message forSession:(uint32_t)sessionId;

/** Fresh Annex-B parameter sets for the given session. */
- (void)broadcastServerDidReceiveParameterSets:(NSData *)parameterSets forSession:(uint32_t)sessionId;

/** An encoded picture for the given session. */
- (void)broadcastServerDidReceiveFrame:(NSData *)annexBPictureData
                            isKeyFrame:(BOOL)isKeyFrame
                                 ptsUs:(uint64_t)ptsUs
                           orientation:(uint8_t)orientation
                            forSession:(uint32_t)sessionId;

/** A fresh OpusHead for the given audio session. */
- (void)broadcastServerDidReceiveAudioParams:(NSData *)opusHead forSession:(uint32_t)sessionId;

/** An encoded Opus packet for the given audio session. */
- (void)broadcastServerDidReceiveAudioPacket:(NSData *)opusPacket
                                       ptsUs:(uint64_t)ptsUs
                                  forSession:(uint32_t)sessionId;

/** The extension disconnected or went silent (watchdog). */
- (void)broadcastServerDidDisconnect;

@end

/**
 The WDA endpoint of the broadcast-extension control connection: listens on the loopback
 control port, accepts a single extension connection at a time and speaks the
 FBBroadcastProtocol wire format in both directions. The existing FBTCPSocket cannot be used
 here because its delegate API discards the received bytes.
 */
@interface FBBroadcastControlServer : NSObject

@property (nonatomic, weak) id<FBBroadcastControlServerDelegate> delegate;

/** YES while an extension connection is established (HELLO received, watchdog content). */
@property (atomic, readonly) BOOL isExtensionConnected;

- (instancetype)initWithPort:(uint16_t)port;

- (instancetype)init NS_UNAVAILABLE;

/** Starts listening on 127.0.0.1:port. */
- (BOOL)startWithError:(NSError **)error;

/** Stops listening and drops any extension connection. */
- (void)stop;

/** Sends SESSION_ADD for the given session id with a JSON configuration payload. */
- (void)sendSessionAdd:(uint32_t)sessionId configuration:(NSDictionary<NSString *, id> *)configuration;

/** Sends SESSION_REMOVE for the given session id. */
- (void)sendSessionRemove:(uint32_t)sessionId;

/** Sends KEYFRAME_REQUEST for the given session id. */
- (void)sendKeyframeRequest:(uint32_t)sessionId;

/** Asks the extension to finish the broadcast. */
- (void)sendStopBroadcast;

@end

NS_ASSUME_NONNULL_END
