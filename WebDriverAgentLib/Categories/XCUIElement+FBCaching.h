/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBCaching)

/*! This property is set to YES if the given element has been resolved from the cache, so it is safe to use the `lastSnapshot` property */
@property (nullable, nonatomic) NSNumber *fb_isResolvedFromCache;

@property (nonatomic, readonly) NSString *fb_cacheId;

@end

NS_ASSUME_NONNULL_END
