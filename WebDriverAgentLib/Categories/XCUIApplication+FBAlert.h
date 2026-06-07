/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBAlert)

/* The accessiblity label used for Safari app */
extern NSString *const FB_SAFARI_APP_NAME;

/**
 Retrieve the current alert element

 @return Alert element instance
 */
- (nullable XCUIElement *)fb_alertElement;

/**
 Retrieve an alert element hosted by the iOS 18+ limited access permission prompt
 process. See https://github.com/appium/appium/issues/20591

 @return Alert element instance if the prompt is present, otherwise nil
 */
+ (nullable XCUIElement *)fb_limitedAccessPromptAlertElement;

@end

NS_ASSUME_NONNULL_END
