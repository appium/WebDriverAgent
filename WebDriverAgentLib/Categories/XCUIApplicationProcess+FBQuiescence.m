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


static void swizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includeAnimations)
{
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    return;
  }

  void (^setProperty)(NSString *, BOOL) = ^(NSString *propertyName, BOOL value) {
    SEL selector = NSSelectorFromString(propertyName);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setArgument:&value atIndex:2];
    [invocation invokeWithTarget:self];
  };
  BOOL isAnimationsIdleNotificationsSupported = [self _supportsAnimationsIdleNotifications];

  setProperty(@"setEventLoopHasIdled:", NO);
  if (isAnimationsIdleNotificationsSupported) {
    setProperty(@"setAnimationsHaveFinished:", NO);
  }

  __block BOOL isSignalSet = NO;
  dispatch_group_t group = dispatch_group_create();
  dispatch_group_enter(group);
  [self _notifyWhenMainRunLoopIsIdle:^{
    if (!isSignalSet) {
      setProperty(@"setEventLoopHasIdled:", YES);
    }
    dispatch_group_leave(group);
  }];
  if (isAnimationsIdleNotificationsSupported) {
    dispatch_group_enter(group);
    [self _notifyWhenAnimationsAreIdle:^{
      if (!isSignalSet) {
        setProperty(@"setAnimationsHaveFinished:", YES);
      }
      dispatch_group_leave(group);
    }];
  }
  dispatch_time_t absoluteTimeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBConfiguration.waitForIdleTimeout * NSEC_PER_SEC));
  BOOL result = 0 == dispatch_group_wait(group, absoluteTimeout);
  isSignalSet = YES;
  if (!result) {
    [FBLogger logFmt:@"The application %@ is still waiting for quiescence after %.2f seconds timeout. This timeout value could be customized by changing the 'waitForIdleTimeout' setting", [self bundleID], FBConfiguration.waitForIdleTimeout];
    setProperty(@"setEventLoopHasIdled:", YES);
    if (isAnimationsIdleNotificationsSupported) {
      setProperty(@"setAnimationsHaveFinished:", YES);
    }
  }
}


@implementation XCUIApplicationProcess (FBQuiescence)

+ (void)load
{
  Method waitForQuiescenceMethod = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  if (waitForQuiescenceMethod != nil) {
    IMP swizzledImp = (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdle;
    method_setImplementation(waitForQuiescenceMethod, swizzledImp);
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
