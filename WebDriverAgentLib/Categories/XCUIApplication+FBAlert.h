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
 Retrieve the current alert element

 @return Alert element instance
 */
- (nullable XCUIElement *)fb_alertElement;

/**
 Retrieve the snapshot of the currently displayed alert, if any, using a
 single upfront application snapshot and purely in-memory tree traversal for
 all subsequent type/candidate checks. This avoids the multiple discrete
 accessibility round trips that fb_alertElement's XCUIElementQuery-based
 lookup performs, which is significantly more expensive while the
 application's main thread is busy (e.g. blocked showing a JS alert in
 Safari). Intended for read-only detection/text-extraction use cases
 (repeatedly polled while waiting for an atom to complete); callers that need
 to interact with (tap) the alert should still use fb_alertElement.

 @return Alert snapshot instance, or nil if no alert is present
 */
- (nullable id<FBXCElementSnapshot>)fb_alertSnapshot;

/**
 Retrieve an alert element hosted by the iOS 18+ limited access permission prompt
 process. See https://github.com/appium/appium/issues/20591

 @return Alert element instance if the prompt is present, otherwise nil
 */
+ (nullable XCUIElement *)fb_limitedAccessPromptAlertElement;

@end

NS_ASSUME_NONNULL_END
