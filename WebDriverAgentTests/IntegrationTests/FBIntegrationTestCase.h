/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

extern NSString *const FBShowAlertButtonName;
extern NSString *const FBShowSheetAlertButtonName;
extern NSString *const FBShowAlertForceTouchButtonName;
extern NSString *const FBTouchesCountLabelIdentifier;
extern NSString *const FBTapsCountLabelIdentifier;

/**
 XCTestCase helper class used for integration tests
 */
@interface FBIntegrationTestCase : XCTestCase
@property (nonatomic, strong, readonly) XCUIApplication *testedApplication;
@property (nonatomic, strong, readonly) XCUIApplication *springboard;

/**
 Launches application and resets side effects of testing like orientation etc.
 */
- (void)launchApplication;

/**
 Navigates integration app to attributes page
 */
- (void)goToAttributesPage;

/**
 Navigates integration app to alerts page
 */
- (void)goToAlertsPage;

/**
 Navigates integration app to touch page
 */
- (void)goToTouchPage;

/**
 Navigates to SpringBoard first page
 */
- (void)goToSpringBoardFirstPage;

/**
 Navigates to SpringBoard path with Extras folder
 */
- (void)goToSpringBoardExtras;

/**
 Navigates to SpringBoard's dashboard
 */
- (void)goToSpringBoardDashboard;

/**
 Navigates integration app to scrolling page
 @param showCells whether should navigate to view with cell or plain scrollview
 */
- (void)goToScrollPageWithCells:(BOOL)showCells;

/**
 Verifies no alerts are present on the page.
 If an alert exists then it is going to be dismissed.
 */
- (void)clearAlert;

/**
 Resets device orientation to portrait mode
 */
- (void)resetOrientation;

@end
