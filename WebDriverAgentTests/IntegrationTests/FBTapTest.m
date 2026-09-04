/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"

#import "FBElementCache.h"
#import "FBTestMacros.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUICoordinate.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBWebDriverAttributes.h"

@interface FBTapTest : FBIntegrationTestCase
@end

// It is recommnded to verify these tests with different iOS versions

@implementation FBTapTest

- (void)verifyTapWithOrientation:(UIDeviceOrientation)orientation
{
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  [self.testedApplication.buttons[FBShowAlertButtonName] tap];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)setUp
{
  // Launch the app everytime to ensure the orientation for each test.
  [super setUp];
  [self launchApplication];
  [self goToAlertsPage];
  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];
  [self resetOrientation];
  [super tearDown];
}

- (void)testTap
{
  [self verifyTapWithOrientation:UIDeviceOrientationPortrait];
}

- (void)testTapInLandscapeLeft
{
  [self verifyTapWithOrientation:UIDeviceOrientationLandscapeLeft];
}

- (void)testTapInLandscapeRight
{

  [self verifyTapWithOrientation:UIDeviceOrientationLandscapeRight];
}

- (void)testTapInPortraitUpsideDown
{
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Failed on Azure Pipeline. Local run succeeded.");
  }
  [self verifyTapWithOrientation:UIDeviceOrientationPortraitUpsideDown];
}

- (void)verifyTapByCoordinatesWithOrientation:(UIDeviceOrientation)orientation
{
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  XCUIElement *dstButton = self.testedApplication.buttons[FBShowAlertButtonName];
  [[dstButton coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)] tap];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testTapCoordinates
{
  [self verifyTapByCoordinatesWithOrientation:UIDeviceOrientationPortrait];
}

- (void)testTapCoordinatesInLandscapeLeft
{
  [self verifyTapByCoordinatesWithOrientation:UIDeviceOrientationLandscapeLeft];
}

- (void)testTapCoordinatesInLandscapeRight
{
  [self verifyTapByCoordinatesWithOrientation:UIDeviceOrientationLandscapeRight];
}

- (void)testTapCoordinatesInPortraitUpsideDown
{
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Failed on Azure Pipeline. Local run succeeded.");
  }
  [self verifyTapByCoordinatesWithOrientation:UIDeviceOrientationPortraitUpsideDown];
}

// appium/appium#16185: skips unless the app's window size actually differs from
// SpringBoard's, e.g. an iPhone-only app on iPad (built with TARGETED_DEVICE_FAMILY=1).
- (void)skipUnlessWindowSizeMismatchesDevice
{
  CGSize appSize = self.testedApplication.frame.size;
  CGSize deviceSize = self.springboard.frame.size;
  if (fabs(appSize.width - deviceSize.width) < 1 && fabs(appSize.height - deviceSize.height) < 1) {
    XCTSkip(@"App window size matches SpringBoard's on this build/device, so it does not "
            "reproduce the compatibility-mode mismatch from appium/appium#16185");
  }
}

// Element-less absolute offsets are never rescaled by XCTest's XCUICoordinate (verified by
// disassembling XCUIAutomation.framework), so this still fails under a window-size mismatch.
- (void)testTapAtElementRectCenterUnderWindowSizeMismatch
{
  [self skipUnlessWindowSizeMismatchesDevice];

  XCUIElement *dstButton = self.testedApplication.buttons[FBShowAlertButtonName];
  CGRect rect = dstButton.wdFrame;
  CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));

  // Mirrors FBBaseActionsSynthesizer's hitpointWithElement:positionOffset:
  // for an absolute (x, y) offset, as used by touch/perform and W3C actions.
  XCUICoordinate *appOrigin = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
  XCUICoordinate *tapPoint = [appOrigin coordinateWithOffset:CGVectorMake(center.x, center.y)];
  [tapPoint tap];

  XCTExpectFailureInBlock(@"element-less absolute offsets are never rescaled by XCTest for a "
                           "compatibility-mode window (appium/appium#16185); starts failing "
                           "loudly here the moment XCTest fixes this itself", ^{
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
  });
}

// FBW3CActionsSynthesizer normalizes element-relative offsets against the element's own
// frame, so this keeps landing correctly under the same window-size mismatch.
- (void)testTapWithElementOffsetUnderWindowSizeMismatch
{
  [self skipUnlessWindowSizeMismatchesDevice];

  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.testedApplication.buttons[FBShowAlertButtonName], @"x": @5, @"y": @5},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @50},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performW3CActions:gesture elementCache:nil error:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

@end
