/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCTIssue+FBPatcher.h"

#import <objc/runtime.h>

static _Bool swizzledShouldInterruptTest(id self, SEL _cmd)
{
  return NO;
}

@implementation XCTIssue (AMPatcher)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
+ (void)load
{
  SEL originalShouldInterruptTest = NSSelectorFromString(@"shouldInterruptTest");
  if (nil == originalShouldInterruptTest) return;
  Method originalShouldInterruptTestMethod = class_getInstanceMethod(self.class, originalShouldInterruptTest);
  if (nil == originalShouldInterruptTestMethod) return;
  method_setImplementation(originalShouldInterruptTestMethod, (IMP)swizzledShouldInterruptTest);
}
#pragma clang diagnostic pop

@end
