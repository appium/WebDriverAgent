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

static void (*original_notifyWhenMainRunLoopIsIdle)(id, SEL, void (^onIdle)(id, void *));
static void (*original_notifyWhenAnimationsAreIdle)(id, SEL, void (^onIdle)(id, void *));


static void swizzledNotifyWhenMainRunLoopIsIdle(id self, SEL _cmd, void (^onIdle)(id, void *))
{
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling", [self bundleID]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      onIdle(nil, nil);
    });
    return;
  }

  __block BOOL didOriginalHandlerWinRace = NO;
  __block BOOL didCustomHandlerWinRace = NO;
  NSLock *handlerGuard = [[NSLock alloc] init];
  void (^onIdleTimed)(id, void *) = ^void(id sender, void *error) {
    [handlerGuard lock];
    didOriginalHandlerWinRace = YES;
    BOOL shouldRunOriginalHandler = !didCustomHandlerWinRace;
    [handlerGuard unlock];
    if (shouldRunOriginalHandler) {
      onIdle(sender, error);
    }
  };

  original_notifyWhenMainRunLoopIsIdle(self, _cmd, onIdleTimed);

  dispatch_time_t nextTimestamp = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBConfiguration.waitForIdleTimeout * NSEC_PER_SEC));
  dispatch_after(nextTimestamp, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [handlerGuard lock];
    didCustomHandlerWinRace = YES;
    BOOL shouldRunCustomHandler = !didOriginalHandlerWinRace;
    [handlerGuard unlock];
    if (shouldRunCustomHandler) {
      [FBLogger logFmt:@"The application %@ is still waiting for being in idle state after %.3f seconds timeout. Making it to believe it is idling",
       [self bundleID], FBConfiguration.waitForIdleTimeout];
      [FBLogger logFmt:@"The timeout value could be customized via '%@'/'%@' settings", WAIT_FOR_IDLE_TIMEOUT, ANIMATION_COOL_OFF_TIMEOUT];
      onIdle(nil, nil);
    }
  });
}

static void swizzledNotifyWhenAnimationsAreIdle(id self, SEL _cmd, void (^onIdle)(id, void *))
{
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe there are no animations", [self bundleID]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      onIdle(nil, nil);
    });
    return;
  }

  __block BOOL didOriginalHandlerWinRace = NO;
  __block BOOL didCustomHandlerWinRace = NO;
  NSLock *handlerGuard = [[NSLock alloc] init];
  void (^onIdleTimed)(id, void *) = ^void(id sender, void *error) {
    [handlerGuard lock];
    didOriginalHandlerWinRace = YES;
    BOOL shouldRunOriginalHandler = !didCustomHandlerWinRace;
    [handlerGuard unlock];
    if (shouldRunOriginalHandler) {
      onIdle(sender, error);
    }
  };

  original_notifyWhenAnimationsAreIdle(self, _cmd, onIdleTimed);

  dispatch_time_t nextTimestamp = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBConfiguration.waitForIdleTimeout * NSEC_PER_SEC));
  dispatch_after(nextTimestamp, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [handlerGuard lock];
    didCustomHandlerWinRace = YES;
    BOOL shouldRunCustomHandler = !didOriginalHandlerWinRace;
    [handlerGuard unlock];
    if (shouldRunCustomHandler) {
      [FBLogger logFmt:@"The application %@ is still waiting for its animations to finish after %.3f seconds timeout. Making it to believe there are no animations",
       [self bundleID], FBConfiguration.waitForIdleTimeout];
      [FBLogger logFmt:@"The timeout value could be customized via '%@'/'%@' settings", WAIT_FOR_IDLE_TIMEOUT, ANIMATION_COOL_OFF_TIMEOUT];
      onIdle(nil, nil);
    }
  });
}


@implementation XCUIApplicationProcess (FBQuiescence)

+ (void)load
{
  Method notifyWhenMainRunLoopIsIdleMethod = class_getInstanceMethod(self.class, @selector(_notifyWhenMainRunLoopIsIdle:));
  if (notifyWhenMainRunLoopIsIdleMethod != nil) {
    IMP swizzledImp = (IMP)swizzledNotifyWhenMainRunLoopIsIdle;
    original_notifyWhenMainRunLoopIsIdle = (void (*)(id, SEL, void (^onIdle)(id, void *))) method_setImplementation(notifyWhenMainRunLoopIsIdleMethod, swizzledImp);
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess _notifyWhenMainRunLoopIsIdle:]"];
  }

  Method notifyWhenAnimationsAreIdleMethod = class_getInstanceMethod(self.class, @selector(_notifyWhenAnimationsAreIdle:));
  if (notifyWhenAnimationsAreIdleMethod != nil) {
    IMP swizzledImp = (IMP)swizzledNotifyWhenAnimationsAreIdle;
    original_notifyWhenAnimationsAreIdle = (void (*)(id, SEL, void (^onIdle)(id, void *))) method_setImplementation(notifyWhenAnimationsAreIdleMethod, swizzledImp);
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess _notifyWhenAnimationsAreIdle:]"];
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
