/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBAudioStreamSession.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Coordinates one or more concurrent audio-capture streams. Sessions only carry data while the
 ReplayKit broadcast extension is connected (it is the sole audio source); each session is keyed
 by an incrementing id and stopped independently.
 */
@interface FBAudioStreamManager : NSObject

+ (instancetype)sharedInstance;

/**
 Creates and starts a new audio capture session.

 @param configuration The capture configuration. If its port is zero, the next free port starting
                       at FBConfiguration.audioCaptureServerPort is assigned.
 @param error If there is an error, upon return contains an NSError describing the problem
 @return The started session (carrying its assigned id and port) or nil in case of a failure
 */
- (nullable FBAudioStreamSession *)startSessionWithConfiguration:(FBAudioCaptureConfiguration *)configuration
                                                           error:(NSError **)error;

/**
 Stops the session with the given id.

 @return NO if no session with that id exists
 */
- (BOOL)stopSessionWithIdentifier:(NSUInteger)identifier;

/** @return The session with the given id, or nil. */
- (nullable FBAudioStreamSession *)sessionWithIdentifier:(NSUInteger)identifier;

/** @return A snapshot of all active session objects. */
- (NSArray<FBAudioStreamSession *> *)activeSessions;

/** @return An array of dictionaries describing all active sessions, ordered by id. */
- (NSArray<NSDictionary *> *)activeSessionsInfo;

/** Stops every active session. */
- (void)stopAllSessions;

@end

NS_ASSUME_NONNULL_END
