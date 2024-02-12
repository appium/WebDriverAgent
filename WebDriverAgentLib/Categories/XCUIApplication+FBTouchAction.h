/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */


#import <XCTest/XCTest.h>
#import "FBElementCache.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBTouchAction)

/**
 Perform complex touch action in scope of the current application.
 
 @param actions Array of dictionaries, whose format is described in W3C spec (https://github.com/jlipps/simple-wd-spec#perform-actions)
 @param elementCache Cached elements mapping for the currrent application. The method assumes all elements are already represented by their actual instances if nil value is set
 @param error If there is an error, upon return contains an NSError object that describes the problem
 @return YES If the touch action has been successfully performed without errors
 */
- (BOOL)fb_performW3CActions:(NSArray *)actions elementCache:(nullable FBElementCache *)elementCache error:(NSError * _Nullable*)error;

@end

NS_ASSUME_NONNULL_END
