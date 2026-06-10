/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement.h"

@interface FBMobilerunActionsIntegrationTests : FBIntegrationTestCase
@end

@implementation FBMobilerunActionsIntegrationTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAlertsPage];
  });
  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];
  [super tearDown];
}

- (CGPoint)alertButtonCenter
{
  XCUIElement *button = self.testedApplication.buttons[FBShowAlertButtonName];
  CGRect frame = button.frame;
  return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

- (void)testTapShowsAlert
{
  CGPoint p = [self alertButtonCenter];
  NSArray *actions = @[
    @{@"type": @"pointerDown", @"x": @(p.x), @"y": @(p.y)},
    @{@"type": @"pointerUp", @"x": @(p.x), @"y": @(p.y)},
  ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performMobilerunActions:actions error:&error]);
  XCTAssertNil(error);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testRejectsNonArrayAndEmpty
{
  NSError *error;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:@[] error:&error]);
  XCTAssertNotNil(error);

  error = nil;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:(NSArray *)@{@"type": @"pointerDown"} error:&error]);
  XCTAssertNotNil(error);
}

- (void)testRejectsPointerUpWithoutDown
{
  NSError *error;
  NSArray *actions = @[@{@"type": @"pointerUp", @"x": @100, @"y": @100}];
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:actions error:&error]);
  XCTAssertNotNil(error);
}

@end
