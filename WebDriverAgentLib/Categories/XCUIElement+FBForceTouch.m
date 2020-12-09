/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBForceTouch.h"

#import "XCUIApplication+FBTouchAction.h"

@implementation XCUIElement (FBForceTouch)

- (BOOL)fb_forceTouchWithPressure:(double)pressure duration:(double)duration error:(NSError **)error
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"action": @"press",
      @"options": @{
          @"element": self,
          @"pressure": @(pressure)
          }
      },
    @{
      @"action": @"wait",
      @"options": @{
          @"ms": @(duration * 1000)
          }
      },
    @{
      @"action": @"release"
      }
    ];
  return [self.application fb_performAppiumTouchActions:gesture elementCache:nil error:error];
}

- (BOOL)fb_forceTouchCoordinate:(CGPoint)relativeCoordinate pressure:(double)pressure duration:(double)duration error:(NSError **)error
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"action": @"press",
      @"options": @{
          @"element": self,
          @"x": @(relativeCoordinate.x),
          @"y": @(relativeCoordinate.y),
          @"pressure": @(pressure)
          }
      },
    @{
      @"action": @"wait",
      @"options": @{
          @"ms": @(duration * 1000)
          }
      },
    @{
      @"action": @"release"
      }
    ];
  return [self.application fb_performAppiumTouchActions:gesture elementCache:nil error:error];
}

@end
