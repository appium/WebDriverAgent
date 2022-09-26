/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplicationProcessDelay.h"
#import <objc/runtime.h>
#import "XCUIApplicationProcess.h"
#import "FBLogger.h"

static void (*orig_set_event_loop_has_idled)(id, SEL, BOOL);
static NSTimeInterval eventloopIdleDelay = 0;
static BOOL isSwizzled = NO;
// '-[XCUIApplicationProcess setEventLoopHasIdled:]' can be called from different queues.
// Lets lock the setup and access to the 'eventloopIdleDelay' variable
static NSLock * lock = nil;

@implementation XCUIApplicationProcessDelay

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"

+ (void)load
{
  lock = [[NSLock alloc] init];
}

#pragma clang diagnostic pop

+ (void)setEventLoopHasIdledDelay:(NSTimeInterval)delay
{
  [lock lock];
  if (!isSwizzled && delay < DBL_EPSILON) {
    // don't swizzle methods until we need to
    [lock unlock];
    return;
  }
  eventloopIdleDelay = delay;
  if (isSwizzled) {
    [lock unlock];
    return;
  }
  [self swizzleSetEventLoopHasIdled];
  [lock unlock];
}

+ (void)disableEventLoopDelay
{
  // Once the methods were swizzled they stay like that since the only change in the implementation
  // is the thread sleep, which is skipped on setting it to zero.
  [self setEventLoopHasIdledDelay:0];
}

+ (void)swizzleSetEventLoopHasIdled {
  Method original = class_getInstanceMethod([XCUIApplicationProcess class], @selector(setEventLoopHasIdled:));
  if (original == nil) {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess setEventLoopHasIdled:]"];
    return;
  }
  orig_set_event_loop_has_idled = (void(*)(id, SEL, BOOL)) method_getImplementation(original);
  Method replace = class_getClassMethod([XCUIApplicationProcessDelay class], @selector(setEventLoopHasIdled:));
  method_setImplementation(original, method_getImplementation(replace));
  isSwizzled = YES;
}

+ (void)setEventLoopHasIdled:(BOOL)idled {
  [lock lock];
  NSTimeInterval delay = eventloopIdleDelay;
  [lock unlock];
  if (delay > 0.0) {
    [FBLogger verboseLog:[NSString stringWithFormat:@"Delaying -[XCUIApplicationProcess setEventLoopHasIdled:] by %.2f seconds", delay]];
    [NSThread sleepForTimeInterval:delay];
  }
  orig_set_event_loop_has_idled(self, _cmd, idled);
}

@end
