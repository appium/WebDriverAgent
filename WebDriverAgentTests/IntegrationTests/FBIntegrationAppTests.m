/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement+FBUtilities.h"

@interface FBIntegrationAppTests : FBIntegrationTestCase
@end

@implementation FBIntegrationAppTests

- (void)setUp
{
  [super setUp];
  [self resetOrientation];
  [self launchApplication];
}

- (void)tearDown
{
  [self resetOrientation];
  [super tearDown];
}

- (void)rotateTo:(UIDeviceOrientation)orientation
{
  XCTAssertTrue([[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation]);
  [self.testedApplication fb_waitUntilStable];
}

- (void)testTouchControlsRemainOnScreenAfterRotation
{
  [self goToTouchPage];
  XCUIElement *canvas = [self.testedApplication descendantsMatchingType:XCUIElementTypeAny][@"touchableView"];
  XCUIElement *taps = self.testedApplication.staticTexts[FBTapsCountLabelIdentifier];
  XCUIElement *touches = self.testedApplication.staticTexts[FBTouchesCountLabelIdentifier];
  NSArray<NSNumber *> *orientations = @[@(UIDeviceOrientationLandscapeLeft),
                                       @(UIDeviceOrientationLandscapeRight),
                                       @(UIDeviceOrientationPortrait)];
  NSUInteger count = 0;
  for (NSNumber *orientation in orientations) {
    [self rotateTo:orientation.integerValue];
    // XCTest can report idle before the rotation animation finishes. Re-read
    // the geometry until the controls have reached their on-screen layout.
    FBAssertWaitTillBecomesTrue(
      CGRectContainsRect(self.testedApplication.frame, canvas.frame)
      && CGRectContainsRect(self.testedApplication.frame, taps.frame)
      && CGRectContainsRect(self.testedApplication.frame, touches.frame));
    CGRect screen = self.testedApplication.frame;
    XCTAssertTrue(CGRectContainsRect(screen, canvas.frame), @"Screen: %@; canvas: %@",
                  NSStringFromCGRect(screen), NSStringFromCGRect(canvas.frame));
    XCTAssertTrue(CGRectContainsRect(screen, taps.frame), @"Screen: %@; taps: %@",
                  NSStringFromCGRect(screen), NSStringFromCGRect(taps.frame));
    XCTAssertTrue(CGRectContainsRect(screen, touches.frame), @"Screen: %@; touches: %@",
                  NSStringFromCGRect(screen), NSStringFromCGRect(touches.frame));
    XCTAssertGreaterThan(CGRectGetHeight(canvas.frame), 0);
    [canvas tap];
    NSString *expectedTaps = [NSString stringWithFormat:@"%lu", (unsigned long)++count];
    FBAssertWaitTillBecomesTrue([taps.label isEqualToString:expectedTaps]);
    XCTAssertEqualObjects(touches.label, @"0");
  }
}

- (void)testScrollRowsResizeWhenRotatingInBothDirections
{
  [self rotateTo:UIDeviceOrientationLandscapeLeft];
  [self goToScrollPageWithCells:NO];
  XCUIElement *scroll = self.testedApplication.scrollViews[@"scrollView"];
  XCUIElement *row = scroll.staticTexts[@"3"];
  NSArray<NSNumber *> *orientations = @[@(UIDeviceOrientationPortrait),
                                       @(UIDeviceOrientationLandscapeRight)];
  for (NSNumber *orientation in orientations) {
    [self rotateTo:orientation.integerValue];
    XCTAssertEqualWithAccuracy(CGRectGetWidth(row.frame), CGRectGetWidth(scroll.frame), 1);
    XCTAssertEqualWithAccuracy(CGRectGetMidX(row.frame), CGRectGetMidX(scroll.frame), 1);
    XCTAssertTrue(row.hittable);
  }
}

@end
