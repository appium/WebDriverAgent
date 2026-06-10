/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBVideoStreamSession.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const FBBroadcastManagerErrorDomain;

typedef NS_ERROR_ENUM(FBBroadcastManagerErrorDomain, FBBroadcastManagerError) {
  /** ReplayKit broadcasts are not available in this environment (Simulator/tvOS). */
  FBBroadcastManagerErrorUnsupported = 1,
  /** The broadcast did not reach the connected state within the allotted time. */
  FBBroadcastManagerErrorTimeout = 2,
  /** The system broadcast picker could not be driven. */
  FBBroadcastManagerErrorPicker = 3,
};

/**
 Coordinates the ReplayKit broadcast extension: owns the loopback control server the extension
 connects to, drives the system broadcast picker UI to start a broadcast, and routes the
 extension's pre-encoded frames into the matching FBVideoStreamSession instances.

 The control server listens permanently (started from FBWebServer), so broadcasts started
 manually from Control Center attach exactly like ones started via the HTTP endpoint.
 */
@interface FBBroadcastManager : NSObject

+ (instancetype)sharedInstance;

/** YES while the broadcast extension is connected to the control server. */
@property (nonatomic, readonly) BOOL isExtensionConnected;

/** Starts the loopback control server. Safe to call multiple times. */
- (void)startListening;

/** Stops the control server and drops the extension connection. */
- (void)stopListening;

/** @return A dictionary describing the broadcast state for the status endpoint. */
- (NSDictionary *)statusDictionary;

/**
 Starts a system broadcast targeting the bundled extension by foregrounding the runner app,
 triggering the broadcast picker and confirming the system sheet via UI automation, then waits
 for the extension to connect. Must be called on the main thread. Idempotent while connected.

 @param timeout The overall time budget in seconds for the broadcast to reach the connected state
 @param confirmButtonLabels Labels to look for on the system confirmation sheet
 @param restoreForegroundApp YES to re-activate the previously active application afterwards
 @param error If there is an error, upon return contains an NSError describing the problem
 @return NO in case of a failure
 */
- (BOOL)startBroadcastWithTimeout:(NSTimeInterval)timeout
              confirmButtonLabels:(NSArray<NSString *> *)confirmButtonLabels
             restoreForegroundApp:(BOOL)restoreForegroundApp
                            error:(NSError **)error;

/**
 Asks the extension to finish the broadcast and waits for it to disconnect.
 Idempotent when no broadcast is running.

 @param error If there is an error, upon return contains an NSError describing the problem
 @return NO in case of a failure
 */
- (BOOL)stopBroadcastWithError:(NSError **)error;

/** Notifies the manager that a capture session started (sends SESSION_ADD when connected). */
- (void)notifySessionAdded:(FBVideoStreamSession *)session;

/** Notifies the manager that a capture session stopped (sends SESSION_REMOVE when connected). */
- (void)notifySessionRemoved:(NSUInteger)identifier;

/** Forwards a key frame request for the given session to the extension. */
- (void)requestKeyFrameForSession:(NSUInteger)identifier;

@end

NS_ASSUME_NONNULL_END
