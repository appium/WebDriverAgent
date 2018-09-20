/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCElementSnapshot+FBHitPoint.h"
#import "FBLogger.h"

@implementation XCElementSnapshot (FBHitPoint)

static BOOL FBHasHitPointProperty = NO;
static BOOL FBHasHitPointResult = NO;
static dispatch_once_t onceHitPoint;

- (NSValue *)fb_hitPoint
{
  dispatch_once(&onceHitPoint, ^{
    FBHasHitPointProperty = [self respondsToSelector:@selector(hitPoint)];
    FBHasHitPointResult = [self respondsToSelector:NSSelectorFromString(@"hitPoint:")];
  });
  @try {
    if (FBHasHitPointProperty) {
      return [NSValue valueWithCGPoint:[self hitPoint]];
    }
    // https://github.com/facebook/WebDriverAgent/issues/934
    if (FBHasHitPointResult) {
      NSError *error;
      SEL mSelector = NSSelectorFromString(@"hitPoint:");
      NSMethodSignature *mSignature = [self methodSignatureForSelector:mSelector];
      NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:mSignature];
      [invocation setTarget:self];
      [invocation setSelector:mSelector];
      [invocation setArgument:&error atIndex:2];
      [invocation invoke];
      id __unsafe_unretained result;
      [invocation getReturnValue:&result];
      if (nil == error && nil != result && nil != [result valueForKey:@"hitPoint"]) {
        return [result valueForKey:@"hitPoint"];
      }
      if (nil != error) {
        [FBLogger logFmt:@"Failed to fetch hit point for %@ - %@", self.debugDescription, error.description];
      }
    }
  } @catch (NSException *e) {
    [FBLogger logFmt:@"Failed to fetch hit point for %@ - %@", self.debugDescription, e.reason];
  }
  return nil;
}

@end
