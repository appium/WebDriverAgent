/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBSwiping.h"

#import "FBLogger.h"
#import "XCUIElement.h"

void swipeWithDirection(NSObject *target, NSString *direction, NSNumber* _Nullable velocity) {
  double velocityValue = .0;
  if (nil != velocity) {
    velocityValue = [velocity doubleValue];
  }

  if (velocityValue > 0) {
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"swipe%@WithVelocity:",
                                         direction.lowercaseString.capitalizedString]);
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setArgument:&velocityValue atIndex:2];
    [invocation invokeWithTarget:target];
  } else {
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"swipe%@",
                                         direction.lowercaseString.capitalizedString]);
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation invokeWithTarget:target];
  }
}

@implementation XCUIElement (FBSwiping)

- (void)fb_swipeWithDirection:(NSString *)direction velocity:(nullable NSNumber*)velocity
{
  swipeWithDirection(self, direction, velocity);
}

@end

#if !TARGET_OS_TV
@implementation XCUICoordinate (FBSwiping)

- (void)fb_swipeWithDirection:(NSString *)direction velocity:(nullable NSNumber*)velocity
{
  swipeWithDirection(self, direction, velocity);
}

@end
#endif
