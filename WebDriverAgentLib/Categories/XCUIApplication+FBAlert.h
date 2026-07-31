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
 Retrieve the snapshot of the currently displayed alert, if any, using a
 single upfront application snapshot and purely in-memory tree traversal for
 all subsequent type/candidate checks - no further accessibility round trips
 are made beyond the one it takes to obtain the application snapshot itself.

 @return Alert snapshot instance, or nil if no alert is present
 */
- (nullable id<FBXCElementSnapshot>)fb_alertSnapshot;

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
