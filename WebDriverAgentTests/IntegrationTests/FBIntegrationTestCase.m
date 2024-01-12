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
#import "FBTestMacros.h"
#import "FBIntegrationTestCase.h"
#import "FBConfiguration.h"
#import "FBMacros.h"
#import "FBRunLoopSpinner.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestConfiguration.h"

NSString *const FBShowAlertButtonName = @"Create App Alert";
NSString *const FBShowSheetAlertButtonName = @"Create Sheet Alert";
NSString *const FBShowAlertForceTouchButtonName = @"Create Alert (Force Touch)";
NSString *const FBTouchesCountLabelIdentifier = @"numberOfTouchesLabel";
NSString *const FBTapsCountLabelIdentifier = @"numberOfTapsLabel";

@interface FBIntegrationTestCase ()
@property (nonatomic, strong) XCUIApplication *testedApplication;
@property (nonatomic, strong) XCUIApplication *springboard;
@end

@implementation FBIntegrationTestCase

- (void)setUp
{
  // Enable it to get extended XCTest logs printed into the console
  // [FBConfiguration enableXcTestDebugLogs];
  [super setUp];
  [FBConfiguration disableRemoteQueryEvaluation];
  [FBConfiguration disableAttributeKeyPathAnalysis];
  [FBConfiguration configureDefaultKeyboardPreferences];
  [FBConfiguration disableApplicationUIInterruptionsHandling];
  [FBConfiguration disableScreenshots];
  self.continueAfterFailure = NO;
  self.springboard = XCUIApplication.fb_systemApplication;
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
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Alerts"].fb_isVisible);
}

- (void)goToAttributesPage
{
  [self.testedApplication.buttons[@"Attributes"] tap];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Button"].fb_isVisible);
}

- (void)goToAlertsPage
{
  [self.testedApplication.buttons[@"Alerts"] tap];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowAlertButtonName].fb_isVisible);
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowSheetAlertButtonName].fb_isVisible);
}

- (void)goToTouchPage
{
  [self.testedApplication.buttons[@"Touch"] tap];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[FBTouchesCountLabelIdentifier].fb_isVisible);
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[FBTapsCountLabelIdentifier].fb_isVisible);
}

- (void)goToSpringBoardFirstPage
{
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(XCUIApplication.fb_systemApplication.icons[@"Safari"].exists);
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(XCUIApplication.fb_systemApplication.icons[@"Calendar"].firstMatch.fb_isVisible);
}

- (void)goToSpringBoardExtras
{
  [self goToSpringBoardFirstPage];
  [self.springboard swipeLeft];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.springboard.icons[@"Extras"].fb_isVisible);
}

- (void)goToSpringBoardDashboard
{
  [self goToSpringBoardFirstPage];
  [self.springboard swipeRight];
  [self.testedApplication fb_waitUntilStable];
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
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"TableView"].fb_isVisible);
  [self.testedApplication.buttons[showCells ? @"TableView": @"ScrollView"] tap];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
}

- (void)clearAlert
{
  [self.testedApplication fb_waitUntilStable];
  [[FBAlert alertWithApplication:self.testedApplication] dismissWithError:nil];
  [self.testedApplication fb_waitUntilStable];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
}

@end
