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

@interface XCUIElement (FBSwiping)

/**
 * Performs swipe gesture on the element
 *
 * @param direction Swipe direction. The following values are supported: up, down, left and right
 * @param velocity Swipe speed in pixels per second. This parameter is only supported since Xcode 11.4
 * nil value means that the default velocity is going to be used.
 */
- (void)fb_swipeWithDirection:(NSString *)direction velocity:(nullable NSNumber*)velocity;

@end

NS_ASSUME_NONNULL_END
