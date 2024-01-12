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

#import "FBIntegrationTestCase.h"
#import "FBElement.h"
#import "FBMacros.h"
#import "FBTestMacros.h"
#import "XCUIApplication.h"
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
  XCTAssertTrue(XCUIApplication.fb_systemApplication.icons[@"Safari"].exists);
  XCTAssertTrue(XCUIApplication.fb_systemApplication.icons[@"Calendar"].firstMatch.exists);
}

- (void)testApplicationTree
{
  XCTAssertNotNil(self.testedApplication.fb_tree);
  XCTAssertNotNil(self.testedApplication.fb_accessibilityTree);
}

- (void)testDeactivateApplication
{
  NSError *error;
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
  NSTimeInterval backgroundDuration = 5.0;
  XCTAssertTrue([self.testedApplication fb_deactivateWithDuration:backgroundDuration error:&error]);
  NSTimeInterval timeElapsed = (clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted) / NSEC_PER_SEC;
  XCTAssertNil(error);
  XCTAssertEqualWithAccuracy(timeElapsed, backgroundDuration, 3.0);
  XCTAssertTrue(self.testedApplication.buttons[@"Alerts"].exists);
}

- (void)testActiveApplication
{
  XCUIApplication *systemApp = XCUIApplication.fb_systemApplication;
  XCTAssertTrue([XCUIApplication fb_activeApplication].buttons[@"Alerts"].fb_isVisible);
  [self goToSpringBoardFirstPage];
  XCTAssertEqualObjects([XCUIApplication fb_activeApplication].bundleID, systemApp.bundleID);
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

- (void)testAccessbilityAudit
{
  if (SYSTEM_VERSION_LESS_THAN(@"17.0")) {
    return;
  }

  NSError *error;
  NSArray *auditIssues1 = [XCUIApplication.fb_activeApplication fb_performAccessibilityAuditWithAuditTypes:~0UL
                                                                                                   error:&error];
  XCTAssertNotNil(auditIssues1);
  XCTAssertNil(error);

  NSMutableSet *set = [NSMutableSet new];
  [set addObject:@"XCUIAccessibilityAuditTypeAll"];
  NSArray *auditIssues2 = [XCUIApplication.fb_activeApplication fb_performAccessibilityAuditWithAuditTypesSet:set.copy
                                                                                                      error:&error];
  XCTAssertEqualObjects(auditIssues1, auditIssues2);
  XCTAssertNil(error);
}

@end
