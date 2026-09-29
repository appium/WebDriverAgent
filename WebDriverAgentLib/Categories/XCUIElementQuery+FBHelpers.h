/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

/** Request-local scratch data. Discard after element response conversion; never
 share across UI actions or commands. Root identity separates snapshot generations. */
@interface FBQuerySnapshotContext : NSObject
- (NSOrderedSet *)snapshotsForRoot:(id<FBXCElementSnapshot>)root;
@end

@interface XCUIElementQuery (FBHelpers)

/**
 Extracts the cached element snapshot from its query.
 No requests to the accessiblity framework is made.
 It is only safe to use this call right after element lookup query
 has been executed.

 @return Either the cached snapshot or nil
 */
- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshot;

- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshotWithContext:(nullable FBQuerySnapshotContext *)context;

@end

NS_ASSUME_NONNULL_END
