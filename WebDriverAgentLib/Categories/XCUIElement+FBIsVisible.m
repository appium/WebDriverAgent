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
#import "XCUIElement+FBVisibleFrame.h"
#import "XCTestPrivateSymbols.h"

NSNumber* _Nullable fetchSnapshotVisibility(id<FBXCElementSnapshot> snapshot)
{
  return nil == snapshot.additionalAttributes ? nil : snapshot.additionalAttributes[FB_XCAXAIsVisibleAttribute];
}

@implementation XCUIElement (FBIsVisible)

- (BOOL)fb_isVisible
{
  @autoreleasepool {
    id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
    return [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_isVisible;
  }
}

@end

@implementation FBXCElementSnapshotWrapper (FBIsVisible)

- (BOOL)fb_hasVisibleDescendants
{
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
  // Shortcircuit here to save time and assume if any of descendants
  // is already determined as visible then the container should be visible as well
  if ([self fb_hasVisibleDescendants]) {
    return YES;
  }

  NSError *error;
  NSNumber *attributeValue = [self fb_attributeValue:FB_XCAXAIsVisibleAttributeName
                                               error:&error];
  if (nil != attributeValue) {
    NSMutableDictionary *updatedValue = [NSMutableDictionary dictionaryWithDictionary:self.additionalAttributes ?: @{}];
    [updatedValue setObject:attributeValue forKey:FB_XCAXAIsVisibleAttribute];
    self.snapshot.additionalAttributes = updatedValue.copy;
    @autoreleasepool {
      return [attributeValue boolValue];
    }
  }

  NSLog(@"Cannot determine visiblity of %@ natively: %@. Defaulting to: %@",
        self.fb_description, error.description, @(NO));
  return NO;
}

@end
