/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBXCElementSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBAlert)

/* The accessiblity label used for Safari app */
extern NSString *const FB_SAFARI_APP_NAME;

/**
 Retrieve the currently displayed alert element, if any, using a single
 predicate-filtered query (Alert, Sheet, or ScrollView type) instead of
 snapshotting and walking the whole application tree - the cost stays
 proportional to the number of matching elements rather than the
 size/depth of the whole app.

 @return Alert element instance, or nil if no alert is present
 */
- (nullable XCUIElement *)fb_alertElement;

/**
 Retrieve the application hosting the iOS 18+ limited access permission prompt,
 cheaply gated on its running state so callers can avoid resolving its alert
 snapshot when the prompt process isn't in the foreground.
 See https://github.com/appium/appium/issues/20591

 @return The prompt application if it is running in the foreground, otherwise nil
 */
+ (nullable XCUIApplication *)fb_limitedAccessPromptApplication;

@end

NS_ASSUME_NONNULL_END
