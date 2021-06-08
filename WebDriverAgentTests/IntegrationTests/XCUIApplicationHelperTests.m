/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <mach/mach_time.h>

#import "FBApplication.h"
#import "FBIntegrationTestCase.h"
#import "FBElement.h"
#import "FBTestMacros.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXCodeCompatibility.h"

@interface XCUIApplicationHelperTests : FBIntegrationTestCase
@end

@implementation XCUIApplicationHelperTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)testQueringSpringboard
{
  [self goToSpringBoardFirstPage];
  XCTAssertTrue(FBApplication.fb_systemApplication.icons[@"Safari"].exists);
  XCTAssertTrue(FBApplication.fb_systemApplication.icons[@"Calendar"].exists);
}

- (void)testApplicationTree
{
  XCTAssertNotNil(self.testedApplication.fb_tree);
  XCTAssertNotNil(self.testedApplication.fb_accessibilityTree);
}

- (void)testDeactivateApplication
{
  NSError *error;
  uint64_t timeStarted = mach_absolute_time();
  NSTimeInterval backgroundDuration = 5.0;
  XCTAssertTrue([self.testedApplication fb_deactivateWithDuration:backgroundDuration error:&error]);
  NSTimeInterval timeElapsed = (mach_absolute_time() - timeStarted) / NSEC_PER_SEC;
  XCTAssertNil(error);
  XCTAssertEqualWithAccuracy(timeElapsed, backgroundDuration, 3.0);
  XCTAssertTrue(self.testedApplication.buttons[@"Alerts"].exists);
}

- (void)testActiveApplication
{
  FBApplication *systemApp = FBApplication.fb_systemApplication;
  XCTAssertTrue([FBApplication fb_activeApplication].buttons[@"Alerts"].fb_isVisible);
  [self goToSpringBoardFirstPage];
  XCTAssertEqualObjects([FBApplication fb_activeApplication].bundleID, systemApp.bundleID);
  XCTAssertTrue(systemApp.icons[@"Safari"].fb_isVisible);
}

- (void)testActiveElement
{
  [self goToAttributesPage];
  XCTAssertNil(self.testedApplication.fb_activeElement);
  XCUIElement *textField = self.testedApplication.textFields[@"aIdentifier"];
  [textField tap];
  FBAssertWaitTillBecomesTrue(nil != self.testedApplication.fb_activeElement);
  XCTAssertEqualObjects(((id<FBElement>)self.testedApplication.fb_activeElement).wdUID,
                        ((id<FBElement>)textField).wdUID);
}

- (void)testActiveApplicationsInfo
{
  NSArray *appsInfo = [XCUIApplication fb_activeAppsInfo];
  XCTAssertTrue(appsInfo.count > 0);
  BOOL isAppActive = NO;
  for (NSDictionary *appInfo in appsInfo) {
    if ([appInfo[@"bundleId"] isEqualToString:self.testedApplication.bundleID]) {
      isAppActive = YES;
      break;
    }
  }
  XCTAssertTrue(isAppActive);
}

- (void)testTestmanagerdVersion
{
  XCTAssertGreaterThan(FBTestmanagerdVersion(), 0);
}

@end
