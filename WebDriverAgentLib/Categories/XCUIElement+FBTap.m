/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBTap.h"

#import "FBMacros.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIApplicationProcessQuiescence.h"

#if !TARGET_OS_TV
@implementation XCUIElement (FBTap)

- (BOOL)fb_tapWithError:(NSError **)error
{
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
    // Tap coordinates calculation issues have been fixed
    // for different device orientations since Xcode 11
    // however, [self tap] calls XCTest quiescence validation before and after the operation which doesn't play nice with animations
    // therfore, disabling animation check and waiting for stability manually
    // see https://github.com/appium/WebDriverAgent/pull/278
    [self fb_waitUntilFrameIsStable];
    [XCUIApplicationProcessQuiescence setAnimationCheckEnabled:NO];
    [self tap];
    [XCUIApplicationProcessQuiescence setAnimationCheckEnabled:YES];
    return YES;
  }

  NSArray<NSDictionary<NSString *, id> *> *tapGesture =
  @[
    @{@"action": @"tap",
      @"options": @{@"element": self}
      }
    ];
  [self fb_waitUntilFrameIsStable];
  return [self.application fb_performAppiumTouchActions:tapGesture elementCache:nil error:error];
}

- (BOOL)fb_tapCoordinate:(CGPoint)relativeCoordinate error:(NSError **)error
{
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
    // Coordinates calculation issues have been fixed
    // for different device orientations since Xcode 11
    XCUICoordinate *startCoordinate = [self coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
    CGVector offset = CGVectorMake(relativeCoordinate.x, relativeCoordinate.y);
    XCUICoordinate *dstCoordinate = [startCoordinate coordinateWithOffset:offset];
    [dstCoordinate tap];
    return YES;
  }

  NSArray<NSDictionary<NSString *, id> *> *tapGesture =
  @[
    @{@"action": @"tap",
      @"options": @{@"element": self,
                    @"x": @(relativeCoordinate.x),
                    @"y": @(relativeCoordinate.y)
                    }
      }
    ];
  [self fb_waitUntilFrameIsStable];
  return [self.application fb_performAppiumTouchActions:tapGesture elementCache:nil error:error];
}

@end
#endif
