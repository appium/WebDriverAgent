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

/**
 Coordinates one or more concurrent screen-capture streams. A single capture loop grabs and
 decodes each screen frame once and fans it out to every active session, so several codecs and
 resolutions can be produced from a single capture. Each session is keyed by an incrementing id
 and is controlled (key frame / stop) independently.
 */
@interface FBVideoStreamManager : NSObject

+ (instancetype)sharedInstance;

/**
 Creates and starts a new capture session.

 @param configuration The capture configuration. If its port is zero, the next free port starting
                       at FBConfiguration.screenCaptureServerPort is assigned.
 @param error If there is an error, upon return contains an NSError describing the problem
 @return The started session (carrying its assigned id and port) or nil in case of a failure
 */
- (nullable FBVideoStreamSession *)startSessionWithConfiguration:(FBScreenCaptureConfiguration *)configuration
                                                          error:(NSError **)error;

/**
 Stops the session with the given id.

 @return NO if no session with that id exists
 */
- (BOOL)stopSessionWithIdentifier:(NSUInteger)identifier;

/**
 Forces a key frame for the session with the given id.

 @return NO if no session with that id exists
 */
- (BOOL)requestKeyFrameForSessionWithIdentifier:(NSUInteger)identifier;

/** @return The session with the given id, or nil. */
- (nullable FBVideoStreamSession *)sessionWithIdentifier:(NSUInteger)identifier;

/** @return A snapshot of all active session objects. */
- (NSArray<FBVideoStreamSession *> *)activeSessions;

/** @return An array of dictionaries describing all active sessions, ordered by id. */
- (NSArray<NSDictionary *> *)activeSessionsInfo;

/** Stops every active session. */
- (void)stopAllSessions;

@end

NS_ASSUME_NONNULL_END
