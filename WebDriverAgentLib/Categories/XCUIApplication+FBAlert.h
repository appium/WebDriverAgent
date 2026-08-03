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

 @param snapshotOut On return, set to the element's snapshot if resolving it
 already required taking one as a side effect (the iPad sheet popover check,
 or the Safari web-alert scan) - left untouched if no snapshot was taken, so
 callers should seed it with nil beforehand. Pass NULL if not needed.
 @return Alert element instance, or nil if no alert is present
 */
- (nullable XCUIElement *)fb_alertElementWithSnapshot:(id<FBXCElementSnapshot> _Nullable * _Nullable)snapshotOut;

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
