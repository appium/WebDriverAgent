/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <objc/runtime.h>

#import "XCUIElement+FBUID.h"

#import "FBElementUtils.h"
#import "FBLogger.h"
#import "XCUIApplication.h"
#import "XCUIElement+FBUtilities.h"

@implementation XCUIElement (FBUID)

- (unsigned long long)fb_accessibiltyId
{
  return [FBElementUtils idWithAccessibilityElement:([self isKindOfClass:XCUIApplication.class]
                                                     ? [(XCUIApplication *)self accessibilityElement]
                                                     : [self fb_takeSnapshot].accessibilityElement)];
}

- (NSString *)fb_uid
{
  return [self isKindOfClass:XCUIApplication.class]
    ? [FBElementUtils uidWithAccessibilityElement:[(XCUIApplication *)self accessibilityElement]]
    : [FBXCElementSnapshotWrapper ensureWrapped:[self fb_takeSnapshot]].fb_uid;
}

@end

@implementation FBXCElementSnapshotWrapper (FBUID)

static void swizzled_validatePredicateWithExpressionsAllowed(id self, SEL _cmd, id predicate, BOOL withExpressionsAllowed)
{
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
+ (void)load
{
  Class XCElementSnapshotCls = objc_lookUpClass("XCElementSnapshot");
  NSAssert(XCElementSnapshotCls != nil, @"Could not locate XCElementSnapshot class");
  Method uidMethod = class_getInstanceMethod(self.class, @selector(fb_uid));
  class_addMethod(XCElementSnapshotCls, @selector(fb_uid), method_getImplementation(uidMethod), method_getTypeEncoding(uidMethod));
  
  // Support for Xcode 14.3 requires disabling the new predicate validator, see https://github.com/appium/appium/issues/18444
  Class XCTElementQueryTransformerPredicateValidatorCls = objc_lookUpClass("XCTElementQueryTransformerPredicateValidator");
  if (XCTElementQueryTransformerPredicateValidatorCls == nil) {
    return;
  }
  Method validatePredicateMethod = class_getClassMethod(XCTElementQueryTransformerPredicateValidatorCls, NSSelectorFromString(@"validatePredicate:withExpressionsAllowed:"));
  if (validatePredicateMethod == nil) {
    [FBLogger log:@"Could not find method +[XCTElementQueryTransformerPredicateValidator validatePredicate:withExpressionsAllowed:]"];
    return;
  }
  IMP swizzledImp = (IMP)swizzled_validatePredicateWithExpressionsAllowed;
  method_setImplementation(validatePredicateMethod, swizzledImp);  
}
#pragma diagnostic pop

- (unsigned long long)fb_accessibiltyId
{
  return [FBElementUtils idWithAccessibilityElement:self.accessibilityElement];
}

+ (nullable NSString *)wdUIDWithSnapshot:(id<FBXCElementSnapshot>)snapshot
{
  return [FBElementUtils uidWithAccessibilityElement:[snapshot accessibilityElement]];
}

- (NSString *)fb_uid
{
  if ([self isKindOfClass:FBXCElementSnapshotWrapper.class]) {
    return [self.class wdUIDWithSnapshot:self.snapshot];
  }
  return [FBElementUtils uidWithAccessibilityElement:[self accessibilityElement]];
}

@end
