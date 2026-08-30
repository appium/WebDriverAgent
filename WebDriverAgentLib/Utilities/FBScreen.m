/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScreen.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXCodeCompatibility.h"
#import "XCUIDevice.h"
#import "XCUIScreen.h"

@implementation FBScreen

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)screensWithError:(NSError **)error
{
  NSArray<XCUIScreen *> *screens = [XCUIDevice.sharedDevice screensOrError:error];
  if (nil == screens) {
    return nil;
  }

  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray arrayWithCapacity:screens.count];
  for (XCUIScreen *screen in screens) {
    CGRect bounds = screen.bounds;
    [result addObject:@{
      @"displayId": @(screen.displayID),
      @"isMain": @(screen.isMainScreen),
      @"scale": @(screen.scale),
      @"bounds": @{
        @"x": @(bounds.origin.x),
        @"y": @(bounds.origin.y),
        @"width": @(bounds.size.width),
        @"height": @(bounds.size.height),
      },
      @"traits": @(screen.traits),
    }];
  }
  return result.copy;
}

+ (long long)displayID
{
  return XCUIScreen.mainScreen.displayID;
}

+ (double)scale
{
  return [XCUIScreen.mainScreen scale];
}

@end
