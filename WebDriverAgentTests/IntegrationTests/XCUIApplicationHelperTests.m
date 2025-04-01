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

void calculateMaxTreeDepth(NSDictionary *tree, NSNumber *currentDepth, NSNumber** maxDepth) {
  if (nil == maxDepth) {
    return;
  }

  NSArray *children = tree[@"children"];
  if (nil == children || 0 == children.count) {
    return;
  }
  for (NSDictionary *child in children) {
    if (currentDepth.integerValue > [*maxDepth integerValue]) {
      *maxDepth = currentDepth;
    }
    calculateMaxTreeDepth(child, @(currentDepth.integerValue + 1), maxDepth);
  }
}

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
  NSDictionary *tree = self.testedApplication.fb_tree;
  XCTAssertNotNil(tree);
  NSNumber *maxDepth;
  calculateMaxTreeDepth(tree, @0, &maxDepth);
  XCTAssertGreaterThan(maxDepth.integerValue, 3);
  XCTAssertNotNil(self.testedApplication.fb_accessibilityTree);
}

- (void)testApplicationTreeAttributesFiltering
{
  NSDictionary *applicationTree = [self.testedApplication fb_tree:[NSSet setWithArray:@[@"visible"]]];
  XCTAssertNotNil(applicationTree);
  XCTAssertNil([applicationTree objectForKey:@"isVisible"], @"'isVisible' key should not be present in the application tree");
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
  // 'elementDescription' is not in this list because it could have
  // different object id's debug description in XCTest.
  NSArray *checkKeys = @[
    @"auditType",
    @"compactDescription",
    @"detailedDescription",
    @"element",
    @"elementAttributes"
  ];

  XCTAssertEqual([auditIssues1 count], [auditIssues2 count]);
  for (int i = 1; i < [auditIssues1 count]; i++) {
    for (NSString *k in checkKeys) {
      XCTAssertEqualObjects(
                            [auditIssues1[i] objectForKey:k],
                            [auditIssues2[i] objectForKey:k]
                            );
    }
  }
  XCTAssertNil(error);
}

@end
