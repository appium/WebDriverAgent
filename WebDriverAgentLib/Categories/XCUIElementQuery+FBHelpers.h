/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElementQuery (FBHelpers)

/**
 Extracts the cached element snapshot from its query.
 No requests to the accessiblity framework is made.
 It is only safe to use this call right after element lookup query
 has been executed.

 @return Either the cached snapshot or nil
 */
- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshot;

@end

NS_ASSUME_NONNULL_END
