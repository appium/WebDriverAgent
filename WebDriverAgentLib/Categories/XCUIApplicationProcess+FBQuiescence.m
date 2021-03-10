/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplicationProcess+FBQuiescence.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBSettings.h"

static void (*original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);

static void swizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includingAnimations)
{
  NSString *bundleId = [self bundleID];
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.waitForIdleTimeout;
  NSTimeInterval previousTimeout = _XCTApplicationStateTimeout();
  _XCTSetApplicationStateTimeout(desiredTimeout);
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  @try {
    original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includingAnimations);
  } @finally {
    _XCTSetApplicationStateTimeout(previousTimeout);
  }
}

@implementation XCUIApplicationProcess (FBQuiescence)

+ (void)load
{
  Method waitForQuiescenceIncludingAnimationsIdleMethod = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  if (nil != waitForQuiescenceIncludingAnimationsIdleMethod) {
    IMP swizzledImp = (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdle;
    original_waitForQuiescenceIncludingAnimationsIdle = (void (*)(id, SEL, BOOL)) method_setImplementation(waitForQuiescenceIncludingAnimationsIdleMethod, swizzledImp);
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:]"];
  }
}

static char XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE;

@dynamic fb_shouldWaitForQuiescence;

- (NSNumber *)fb_shouldWaitForQuiescence
{
  id result = objc_getAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE);
  if (nil == result) {
    return @(YES);
  }
  return (NSNumber *)result;
}

- (void)setFb_shouldWaitForQuiescence:(NSNumber *)value
{
  objc_setAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
