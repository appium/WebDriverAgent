/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBExtSessionPipeline.h"

NS_ASSUME_NONNULL_BEGIN

@class FBExtBroadcastClient;

@protocol FBExtBroadcastClientDelegate <NSObject>

/** WDA asked the extension to finish the broadcast. */
- (void)broadcastClientDidRequestStop:(FBExtBroadcastClient *)client;

/** The connection to WDA could not be (re-)established; the broadcast should be finished. */
- (void)broadcastClient:(FBExtBroadcastClient *)client didFailPermanently:(NSError *)error;

@end

/**
 The extension's endpoint of the WDA control connection: connects to WDA's loopback control
 port, answers session add/remove/keyframe requests by managing FBExtSessionPipeline instances,
 sends the HELLO/heartbeat messages and pushes the pipelines' encoded output.
 */
@interface FBExtBroadcastClient : NSObject <FBExtMessageSink>

@property (nonatomic, weak) id<FBExtBroadcastClientDelegate> delegate;

/** Stats fed into the heartbeat; updated by the sample handler. */
@property (atomic) BOOL paused;
@property (atomic) uint64_t framesReceived;
@property (atomic) uint8_t currentOrientation;
@property (atomic) size_t screenWidth;
@property (atomic) size_t screenHeight;

/** A point-in-time snapshot of the active pipelines, safe to read from any thread. */
@property (atomic, copy, readonly) NSDictionary<NSNumber *, FBExtSessionPipeline *> *activePipelines;

/** Starts connecting to the WDA control port (with retries). */
- (void)start;

/** Tears down all pipelines and closes the connection (no reconnect attempts). */
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
