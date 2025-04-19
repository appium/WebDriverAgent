/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBAccessibility.h"

#import "FBConfiguration.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIElement+FBUtilities.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"

@implementation XCUIElement (FBAccessibility)

- (BOOL)fb_isAccessibilityElement
{
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  return [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_isAccessibilityElement;
}

@end

@implementation FBXCElementSnapshotWrapper (FBAccessibility)

- (BOOL)fb_isAccessibilityElement
{
  NSNumber *isAccessibilityElement = self.additionalAttributes[FB_XCAXAIsElementAttribute];
  if (nil != isAccessibilityElement) {
    return isAccessibilityElement.boolValue;
  }

  NSError *error;
  NSNumber *attributeValue = [self fb_attributeValue:FB_XCAXAIsElementAttributeName
                                               error:&error];
  if (nil != attributeValue) {
    NSMutableDictionary *updatedValue = [NSMutableDictionary dictionaryWithDictionary:self.additionalAttributes ?: @{}];
    [updatedValue setObject:attributeValue forKey:FB_XCAXAIsElementAttribute];
    self.snapshot.additionalAttributes = updatedValue.copy;
    return [attributeValue boolValue];
  }

  NSLog(@"Cannot determine accessibility of '%@' natively: %@. Defaulting to: %@",
        self.fb_description, error.description, @(NO));
  return NO;
}

@end
