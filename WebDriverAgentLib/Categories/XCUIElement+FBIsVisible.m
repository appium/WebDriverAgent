/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBIsVisible.h"

#import "FBElementUtils.h"
#import "FBXCodeCompatibility.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestPrivateSymbols.h"

#define AX_FETCH_TIMEOUT 0.3

NSNumber* _Nullable fetchSnapshotVisibility(id<FBXCElementSnapshot> snapshot)
{
  return nil == snapshot.additionalAttributes ? nil : snapshot.additionalAttributes[FB_XCAXAIsVisibleAttribute];
}

@implementation XCUIElement (FBIsVisible)

- (BOOL)fb_isVisible
{
  id<FBXCElementSnapshot> snapshot = [self fb_takeSnapshot:NO];
  return [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_isVisible;
}

@end

@implementation FBXCElementSnapshotWrapper (FBIsVisible)

- (BOOL)fb_hasVisibleAncestorsOrDescendants
{
  if (nil != [self fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeAny)]
                                        filter:^BOOL(id<FBXCElementSnapshot>  _Nonnull parent) {
    return [fetchSnapshotVisibility(parent) boolValue];
  }]) {
    return YES;
  }
  for (id<FBXCElementSnapshot> descendant in (self._allDescendants ?: @[])) {
    if ([fetchSnapshotVisibility(descendant) boolValue]) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)fb_isVisible
{
  NSNumber *isVisible = fetchSnapshotVisibility(self);
  if (nil != isVisible) {
    return isVisible.boolValue;
  }

  // Fetching the attribute value is expensive.
  // Shortcircuit here to save time and assume if any of descendants or ancestors
  // are already determined as visible then the container should be visible as well
  if ([self fb_hasVisibleAncestorsOrDescendants]) {
    return YES;
  }

  NSError *error;
  NSNumber *attributeValue = [self fb_attributeValue:FB_XCAXAIsVisibleAttributeName
                                             timeout:AX_FETCH_TIMEOUT
                                               error:&error];
  if (nil != attributeValue) {
    return [attributeValue boolValue];
  }

  // If we fail to fetch the "true" visibility from AX then fallback to
  // the lousy `hittable`-based detection method
  BOOL fallbackResult = nil != [self fb_hitPoint];
  NSLog(@"Cannot determine '%@' visibility natively: %@. Defaulting to: %@",
        self.fb_description, error.description, @(fallbackResult));
  return fallbackResult;
}

@end
