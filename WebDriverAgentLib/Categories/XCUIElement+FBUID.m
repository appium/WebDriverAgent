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
  return [self.class wdUIDWithSnapshot:self.snapshot];
}

@end
