/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplicationProcessQuiescence.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBLogger.h"
#import "XCUIApplicationProcess.h"

static void (*original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);


static void swizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includeAnimations)
{
  if (!FBConfiguration.shouldWaitForQuiescence || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    return;
  }
  original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includeAnimations);

  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t queue = dispatch_queue_create("com.facebook.wda.animations", 0);

  void (^activateProperty)(NSString *) = ^(NSString *propertyName) {
    SEL selector = NSSelectorFromString(propertyName);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    BOOL yes = YES;
    [invocation setArgument:&yes atIndex:2];
    [invocation invokeWithTarget:self];
  };
  dispatch_group_async(group, queue, ^{
    [self _notifyWhenMainRunLoopIsIdle:^{
      activateProperty(@"setEventLoopHasIdled:");
    }];
  });
  if ([self _supportsAnimationsIdleNotifications]) {
    dispatch_group_async(group, queue, ^{
      [self _notifyWhenAnimationsAreIdle:^{
        activateProperty(@"setAnimationsHaveFinished:");
      }];
    });
  }

  dispatch_time_t absoluteTimeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBConfiguration.waitForIdleTimeout * NSEC_PER_SEC));
  BOOL result = 0 == dispatch_group_wait(group, absoluteTimeout);
  if (!result) {
    [FBLogger logFmt:@"The applicaion %@ is still waiting for quiescence after %.2f seconds timeout. This timeout could be customized by 'waitForIdleTimeout' setting", [self bundleID], FBConfiguration.waitForIdleTimeout];
  }
}


@implementation XCUIApplicationProcessQuiescence

+ (void)load
{
  Method waitForQuiescenceMethod = class_getInstanceMethod(XCUIApplicationProcess.class, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  if (waitForQuiescenceMethod != nil) {
    IMP swizzledImp = (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdle;
    original_waitForQuiescenceIncludingAnimationsIdle = (void (*)(id, SEL, BOOL))method_setImplementation(waitForQuiescenceMethod, swizzledImp);
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:]"];
  }
}

@end
