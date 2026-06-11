/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBScreen.h"
#import "FBTestMacros.h"
#import "XCUIApplication+FBQuiescence.h"
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
  // Coordinates are passed in device pixels (center point * scale); the fast path divides by the
  // same scale before dispatch, so the tap must land on the button regardless of screen scale.
  CGFloat scale = (CGFloat)[FBScreen scale];
  CGPoint p = [self alertButtonCenter];
  NSArray *actions = @[
    @{@"type": @"pointerDown", @"x": @(p.x * scale), @"y": @(p.y * scale)},
    @{@"type": @"pointerUp", @"x": @(p.x * scale), @"y": @(p.y * scale)},
  ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performMobilerunActions:actions scale:scale error:&error]);
  XCTAssertNil(error);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testLeadingMoveThenTapShowsAlert
{
  // W3C-style sequence: position with a leading pointerMove, then pointerDown/up. The leading
  // move already presses the touch down, so the following pointerDown must not double-press.
  CGFloat scale = (CGFloat)[FBScreen scale];
  CGPoint p = [self alertButtonCenter];
  NSArray *actions = @[
    @{@"type": @"pointerMove", @"x": @(p.x * scale), @"y": @(p.y * scale)},
    @{@"type": @"pointerDown", @"x": @(p.x * scale), @"y": @(p.y * scale)},
    @{@"type": @"pointerUp", @"x": @(p.x * scale), @"y": @(p.y * scale)},
  ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performMobilerunActions:actions scale:scale error:&error]);
  XCTAssertNil(error);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testRejectsNonArrayAndEmpty
{
  NSError *error;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:@[] scale:1.0 error:&error]);
  XCTAssertNotNil(error);

  error = nil;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:(NSArray *)@{@"type": @"pointerDown"} scale:1.0 error:&error]);
  XCTAssertNotNil(error);
}

- (void)testRejectsPointerUpWithoutDown
{
  NSError *error;
  NSArray *actions = @[@{@"type": @"pointerUp", @"x": @100, @"y": @100}];
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:actions scale:1.0 error:&error]);
  XCTAssertNotNil(error);
}

- (void)testPressDragZeroDistanceShowsAlert
{
  // A zero-distance press-and-drag is a plain long press; the touch lifts inside the button, so
  // touch-up-inside must fire. Positive control for testPressDragAwaySuppressesAlert.
  CGPoint p = [self alertButtonCenter];
  [self.testedApplication fb_mobilerunPressAndDragFromPoint:p
                                                    toPoint:p
                                              pressDuration:0.3
                                                   velocity:300
                                               holdDuration:0.2];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testPressDragAwaySuppressesAlert
{
  // Dragging off the button before lifting turns the touch into touch-up-outside; no alert may
  // appear. Together with the zero-distance test this proves the drag actually moves the touch.
  CGPoint from = [self alertButtonCenter];
  CGPoint to = CGPointMake(from.x, from.y + 150);
  [self.testedApplication fb_mobilerunPressAndDragFromPoint:from
                                                    toPoint:to
                                              pressDuration:0.3
                                                   velocity:300
                                               holdDuration:0.2];
  [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  XCTAssertEqual(self.testedApplication.alerts.count, 0);
}

- (void)testPressDragRestoresQuiescenceFlag
{
  // The gesture suppresses quiescence waits only for its own duration and must restore the
  // previous value afterwards.
  CGPoint p = [self alertButtonCenter];
  self.testedApplication.fb_shouldWaitForQuiescence = YES;
  [self.testedApplication fb_mobilerunPressAndDragFromPoint:p
                                                    toPoint:p
                                              pressDuration:0.1
                                                   velocity:300
                                               holdDuration:0];
  XCTAssertTrue(self.testedApplication.fb_shouldWaitForQuiescence);
  [self clearAlert];

  self.testedApplication.fb_shouldWaitForQuiescence = NO;
  [self.testedApplication fb_mobilerunPressAndDragFromPoint:p
                                                    toPoint:p
                                              pressDuration:0.1
                                                   velocity:300
                                               holdDuration:0];
  XCTAssertFalse(self.testedApplication.fb_shouldWaitForQuiescence);
}

@end
