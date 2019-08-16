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
#import "XCElementSnapshot+FBHelpers.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIElement+FBUtilities.h"

@implementation XCUIElement (FBAccessibility)

- (BOOL)fb_isAccessibilityElement
{
  return (self.fb_snapshotWithAttributes ?: self.fb_lastSnapshot).fb_isAccessibilityElement;
}

@end

@implementation XCElementSnapshot (FBAccessibility)

- (BOOL)fb_isAccessibilityElement
{
  NSNumber *isAccessibilityElement = self.additionalAttributes[FB_XCAXAIsElementAttribute];
  if (nil != isAccessibilityElement) {
    return isAccessibilityElement.boolValue;
  }
  
  return [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsElementAttributeName] boolValue];
}

@end
