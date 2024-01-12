/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"

#import "FBElementCache.h"
#import "FBTestMacros.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement+FBIsVisible.h"

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

@end
