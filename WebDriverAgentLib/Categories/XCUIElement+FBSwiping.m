/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBSwiping.h"
#import "XCUIElement.h"

@implementation XCUIElement (FBSwiping)

- (void)fb_swipeWithDirection:(NSString *)direction velocity:(nullable NSNumber*)velocity
{
  double velocityValue = .0;
  if (nil != velocity && [self respondsToSelector:@selector(swipeUpWithVelocity:)]) {
    velocityValue = [velocity doubleValue];
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  if (velocityValue > 0) {
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"swipe%@WithVelocity:", direction.lowercaseString.capitalizedString]);
    [self performSelector:selector withObject:@(velocityValue)];
  } else {
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"swipe%@", direction.lowercaseString.capitalizedString]);
    [self performSelector:selector];
  }
#pragma clang diagnostic pop
}

@end
