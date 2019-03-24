/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBAlert.h"
#import "FBSpringboardApplication.h"
#import "FBTestMacros.h"
#import "FBIntegrationTestCase.h"
#import "FBConfiguration.h"
#import "FBMacros.h"
#import "FBRunLoopSpinner.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"

NSString *const FBShowAlertButtonName = @"Create App Alert";
NSString *const FBShowSheetAlertButtonName = @"Create Sheet Alert";
NSString *const FBShowAlertForceTouchButtonName = @"Create Alert (Force Touch)";

@interface FBIntegrationTestCase ()
@property (nonatomic, strong) XCUIApplication *testedApplication;
@property (nonatomic, strong) FBSpringboardApplication *springboard;
@end

@implementation FBIntegrationTestCase

- (void)setUp
{
  [super setUp];
  [FBConfiguration disableRemoteQueryEvaluation];
  [FBConfiguration disableAttributeKeyPathAnalysis];
  self.continueAfterFailure = NO;
  self.springboard = [FBSpringboardApplication fb_springboard];
  self.testedApplication = [XCUIApplication new];
}

- (void)resetOrientation
{
  if ([XCUIDevice sharedDevice].orientation != UIDeviceOrientationPortrait) {
    [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:UIDeviceOrientationPortrait];
  }
}

- (void)launchApplication
{
  [self.testedApplication launch];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Alerts"].fb_isVisible);
}

- (void)goToAttributesPage
{
  [self.testedApplication.buttons[@"Attributes"] tap];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Button"].fb_isVisible);
}

- (void)goToAlertsPage
{
  [self.testedApplication.buttons[@"Alerts"] tap];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowAlertButtonName].fb_isVisible);
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowSheetAlertButtonName].fb_isVisible);
}

- (void)goToSpringBoardFirstPage
{
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue([FBSpringboardApplication fb_springboard].icons[@"Safari"].exists);
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue([FBSpringboardApplication fb_springboard].icons[@"Calendar"].fb_isVisible);
}

- (void)goToSpringBoardExtras
{
  [self goToSpringBoardFirstPage];
  [self.springboard swipeLeft];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.springboard.icons[@"Extras"].fb_isVisible);
}

- (void)goToSpringBoardDashboard
{
  [self goToSpringBoardFirstPage];
  [self.springboard swipeRight];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  NSPredicate *predicate =
    [NSPredicate predicateWithFormat:
     @"%K IN %@",
     FBStringify(XCUIElement, identifier),
     @[@"SBSearchEtceteraIsolatedView", @"SpotlightSearchField"]
   ];
  FBAssertWaitTillBecomesTrue([[self.springboard descendantsMatchingType:XCUIElementTypeAny] elementMatchingPredicate:predicate].fb_isVisible);
  FBAssertWaitTillBecomesTrue(!self.springboard.icons[@"Calendar"].fb_isVisible);
}

- (void)goToScrollPageWithCells:(BOOL)showCells
{
  [self.testedApplication.buttons[@"Scrolling"] tap];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"TableView"].fb_isVisible);
  [self.testedApplication.buttons[showCells ? @"TableView": @"ScrollView"] tap];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
}

- (void)clearAlert
{
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  [[FBAlert alertWithApplication:self.testedApplication] dismissWithError:nil];
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
}

@end
