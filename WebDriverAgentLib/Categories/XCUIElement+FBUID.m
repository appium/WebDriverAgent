/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBUID.h"

#import "FBElementUtils.h"
#import "XCUIApplication.h"
#import "XCUIElement+FBUtilities.h"
#import <objc/runtime.h>

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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
+ (void)load
{
  Class XCElementSnapshotCls = objc_lookUpClass("XCElementSnapshot");
  if (XCElementSnapshotCls != nil)
  {
    Method uidMethod = class_getInstanceMethod(self.class, @selector(fb_uid));
    class_addMethod(XCElementSnapshotCls, @selector(fb_uid), method_getImplementation(uidMethod), method_getTypeEncoding(uidMethod));
  }
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
