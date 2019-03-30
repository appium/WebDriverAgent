/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplicationProcessQuiescence.h"
#import "XCUIApplicationProcess.h"
#import <objc/runtime.h>
#import "FBLogger.h"

static void (*original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);
static BOOL isWaitForQuiescence = NO;

@implementation XCUIApplicationProcessQuiescence

+ (void)load
{
  Method waitForQuiescenceMethod = class_getInstanceMethod([XCUIApplicationProcess class], @selector(waitForQuiescenceIncludingAnimationsIdle:));
  if (waitForQuiescenceMethod != nil) {
    original_waitForQuiescenceIncludingAnimationsIdle = (void(*)(id, SEL, BOOL)) method_getImplementation(waitForQuiescenceMethod);
    Method newMethod = class_getClassMethod([XCUIApplicationProcessQuiescence class], @selector(swizzledWaitForQuiescenceIncludingAnimationsIdle:));
    method_setImplementation(waitForQuiescenceMethod, method_getImplementation(newMethod));
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:]"];
  }
}

+ (void)setQuiescenceCheck:(BOOL)value
{
  isWaitForQuiescence = value;
}

+ (void)swizzledWaitForQuiescenceIncludingAnimationsIdle:(BOOL)includeAnimations
{
  if (!isWaitForQuiescence) {
    return;
  }
  original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includeAnimations);
}

@end
