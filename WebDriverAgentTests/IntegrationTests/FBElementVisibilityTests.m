/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBMacros.h"
#import "FBTestMacros.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"

@interface FBElementVisibilityTests : FBIntegrationTestCase
@end

@implementation FBElementVisibilityTests

- (void)testSpringBoardIcons
{
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Not applicable to iPad");
  }
  [self launchApplication];
  [self goToSpringBoardFirstPage];
  [self.springboard fb_waitUntilStable];

  // Calendar can match both its app icon and a widget on iOS 15+.
  FBAssertWaitTillBecomesTrue(self.springboard.icons[@"Calendar"].firstMatch.fb_isVisible);
  // Safari is in the dock; Reminders is not reliably visible on the first page
  // of CI simulators. Wait for the Home transition before checking visibility.
  FBAssertWaitTillBecomesTrue(self.springboard.icons[@"Safari"].firstMatch.fb_isVisible);

  // Check the fixture icon on another page.
  XCTAssertFalse(self.springboard.icons[@"IntegrationApp"].firstMatch.fb_isVisible);
}

- (void)testIconsFromSearchDashboard
{
  if (FBIntegrationTestCase.isRunningInCI) {
    // Causes: Failure fetching attributes for element <XCAccessibilityElement>
    // Device element: Error Domain=XCTDaemonErrorDomain Code=13 "Value for attribute 5017 is an error."
    XCTSkip(@"Fails with XCTDaemonErrorDomain Code=13 on CI simulators");
  }

  [self launchApplication];
  [self goToSpringBoardDashboard];
  XCTAssertFalse(self.springboard.icons[@"Reminders"].fb_isVisible);
  XCTAssertFalse([[[self.springboard descendantsMatchingType:XCUIElementTypeIcon]
                   matchingIdentifier:@"IntegrationApp"]
                  firstMatch].fb_isVisible);
}

- (void)testTableViewCells
{
  [self launchApplication];
  [self goToScrollPageWithCells:YES];
  for (int i = 0 ; i < 10 ; i++) {
    FBAssertWaitTillBecomesTrue(self.testedApplication.cells.allElementsBoundByIndex[i].fb_isVisible);
    FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts.allElementsBoundByIndex[i].fb_isVisible);
  }
}

@end
