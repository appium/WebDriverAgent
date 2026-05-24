/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIDevice+FBRotation.h"

#import "FBConfiguration.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBUtilities.h"

# if !TARGET_OS_TV

@implementation XCUIDevice (FBRotation)

- (BOOL)fb_setDeviceInterfaceOrientation:(UIDeviceOrientation)orientation
{
  XCUIApplication *application = XCUIApplication.fb_activeApplication;
  [XCUIDevice sharedDevice].orientation = orientation;
  return [self waitUntilInterfaceIsAtOrientation:orientation application:application];
}

- (BOOL)fb_setDeviceRotation:(NSDictionary *)rotationObj
{
  NSArray<NSNumber *> *keysForRotationObj = [self.fb_rotationMapping allKeysForObject:rotationObj];
  if (keysForRotationObj.count == 0) {
    return NO;
  }
  UIDeviceOrientation orientation = (UIDeviceOrientation)keysForRotationObj.firstObject.integerValue;
  XCUIApplication *application = XCUIApplication.fb_activeApplication;
  [XCUIDevice sharedDevice].orientation = orientation;
  return [self waitUntilInterfaceIsAtOrientation:orientation application:application];
}

static UIInterfaceOrientation FBInterfaceOrientationFromDeviceOrientation(UIDeviceOrientation orientation)
{
  switch (orientation) {
    case UIDeviceOrientationPortrait:
      return UIInterfaceOrientationPortrait;
    case UIDeviceOrientationPortraitUpsideDown:
      return UIInterfaceOrientationPortraitUpsideDown;
    case UIDeviceOrientationLandscapeLeft:
      return UIInterfaceOrientationLandscapeRight;
    case UIDeviceOrientationLandscapeRight:
      return UIInterfaceOrientationLandscapeLeft;
    case UIDeviceOrientationUnknown:
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationFaceDown:
    default:
      return UIInterfaceOrientationUnknown;
  }
}

- (BOOL)waitUntilInterfaceIsAtOrientation:(UIDeviceOrientation)orientation application:(XCUIApplication *)application
{
  // Tapping elements immediately after rotation may fail due to way UIKit is handling touches.
  // We should wait till UI cools off, before continuing
  [application fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];

  return application.interfaceOrientation == FBInterfaceOrientationFromDeviceOrientation(orientation);
}

- (NSDictionary *)fb_rotationMapping
{
    static NSDictionary *rotationMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rotationMap =
        @{
          @(UIDeviceOrientationUnknown) : @{@"x" : @(-1), @"y" : @(-1), @"z" : @(-1)},
          @(UIDeviceOrientationPortrait) : @{@"x" : @(0), @"y" : @(0), @"z" : @(0)},
          @(UIDeviceOrientationPortraitUpsideDown) : @{@"x" : @(0), @"y" : @(0), @"z" : @(180)},
          @(UIDeviceOrientationLandscapeLeft) : @{@"x" : @(0), @"y" : @(0), @"z" : @(270)},
          @(UIDeviceOrientationLandscapeRight) : @{@"x" : @(0), @"y" : @(0), @"z" : @(90)},
          @(UIDeviceOrientationFaceUp) : @{@"x" : @(90), @"y" : @(0), @"z" : @(0)},
          @(UIDeviceOrientationFaceDown) : @{@"x" : @(270), @"y" : @(0), @"z" : @(0)},
          };
    });
    return rotationMap;
}

@end
#endif
