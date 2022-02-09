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


#if !TARGET_OS_TV
@implementation XCUIElement (FBTap)

- (BOOL)fb_tapWithError:(NSError **)error
{
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
    [self tap];
    return YES;
  }

  NSArray<NSDictionary<NSString *, id> *> *tapGesture =
  @[
    @{@"action": @"tap",
      @"options": @{@"element": self}
      }
    ];
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
  return [self.application fb_performAppiumTouchActions:tapGesture elementCache:nil error:error];
}

@end
#endif
