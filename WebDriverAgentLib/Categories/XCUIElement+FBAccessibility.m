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
  id<FBXCElementSnapshot> snapshot = [self fb_snapshotWithAttributes:@[FB_XCAXAIsElementAttributeName]
                                                            maxDepth:@1];
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
  
  return [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsElementAttributeName] boolValue];
}

@end
