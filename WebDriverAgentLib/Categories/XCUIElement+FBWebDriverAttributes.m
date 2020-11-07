/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBWebDriverAttributes.h"

#import <objc/runtime.h>

#import "FBElementTypeTransformer.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "XCUIElement+FBAccessibility.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "FBElementUtils.h"
#import "XCTestPrivateSymbols.h"

@implementation XCUIElement (WebDriverAttributesForwarding)

- (XCElementSnapshot *)fb_snapshotForAttributeName:(NSString *)name
{
  // These attrbiutes are special, because we can only retrieve them from
  // the snapshot if we explicitly ask XCTest to include them into the query while taking it.
  // That is why fb_snapshotWithAllAttributes method must be used instead of the default snapshot
  // call
  if ([name isEqualToString:FBStringify(XCUIElement, isWDVisible)]) {
    return [self fb_snapshotWithAttributes:@[FB_XCAXAIsVisibleAttributeName]
                                  maxDepth:@1];
  }
  if ([name isEqualToString:FBStringify(XCUIElement, isWDAccessible)]) {
    return [self fb_snapshotWithAttributes:@[FB_XCAXAIsElementAttributeName]
                                  maxDepth:@1];
  }
  if ([name isEqualToString:FBStringify(XCUIElement, isWDAccessibilityContainer)]) {
    return [self fb_snapshotWithAttributes:@[FB_XCAXAIsElementAttributeName]
                                  maxDepth:nil];
  }
  
  return self.fb_takeSnapshot;
}

- (id)fb_valueForWDAttributeName:(NSString *)name
{
  NSString *wdAttributeName = [FBElementUtils wdAttributeNameForAttributeName:name];
  XCElementSnapshot *snapshot = [self fb_snapshotForAttributeName:wdAttributeName];
  return [snapshot fb_valueForWDAttributeName:name];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  struct objc_method_description descr = protocol_getMethodDescription(@protocol(FBElement), aSelector, YES, YES);
  SEL webDriverAttributesSelector = descr.name;
  return nil == webDriverAttributesSelector
    ? nil
    : [self fb_snapshotForAttributeName:NSStringFromSelector(webDriverAttributesSelector)];
}

@end


@implementation XCElementSnapshot (WebDriverAttributes)

- (id)fb_valueForWDAttributeName:(NSString *)name
{
  return [self valueForKey:[FBElementUtils wdAttributeNameForAttributeName:name]];
}

- (NSString *)wdValue
{
  id value = self.value;
  XCUIElementType elementType = self.elementType;
  if (elementType == XCUIElementTypeStaticText) {
    NSString *label = self.label;
    value = FBFirstNonEmptyValue(value, label);
  } else if (elementType == XCUIElementTypeButton) {
    NSNumber *isSelected = self.isSelected ? @YES : nil;
    value = FBFirstNonEmptyValue(value, isSelected);
  } else if (elementType == XCUIElementTypeSwitch) {
    value = @([value boolValue]);
  } else if (elementType == XCUIElementTypeTextView ||
             elementType == XCUIElementTypeTextField ||
             elementType == XCUIElementTypeSecureTextField) {
    NSString *placeholderValue = self.placeholderValue;
    value = FBFirstNonEmptyValue(value, placeholderValue);
  }
  value = FBTransferEmptyStringToNil(value);
  if (value) {
    value = [NSString stringWithFormat:@"%@", value];
  }
  return value;
 }

- (NSString *)wdName
{
  NSString *identifier = self.identifier;
  if (nil != identifier && identifier.length != 0) {
    return identifier;
  }
  NSString *label = self.label;
  return FBTransferEmptyStringToNil(label);
}

- (NSString *)wdLabel
{
  NSString *label = self.label;
  XCUIElementType elementType = self.elementType;
  if (elementType == XCUIElementTypeTextField || elementType == XCUIElementTypeSecureTextField ) {
    return label;
  }
  return FBTransferEmptyStringToNil(label);
}

- (NSString *)wdType
{
  return [FBElementTypeTransformer stringWithElementType:self.elementType];
}

- (NSString *)wdUID
{
  return self.fb_uid;
}

- (CGRect)wdFrame
{
  return CGRectIntegral(self.frame);
}

- (BOOL)isWDVisible
{
  return self.fb_isVisible;
}

#if TARGET_OS_TV
- (BOOL)isWDFocused
{
  return self.hasFocus;
}
#endif

- (BOOL)isWDAccessible
{
  XCUIElementType elementType = self.elementType;
  // Special cases:
  // Table view cell: we consider it accessible if it's container is accessible
  // Text fields: actual accessible element isn't text field itself, but nested element
  if (elementType == XCUIElementTypeCell) {
    if (!self.fb_isAccessibilityElement) {
      XCElementSnapshot *containerView = [[self children] firstObject];
      if (!containerView.fb_isAccessibilityElement) {
        return NO;
      }
    }
  } else if (elementType != XCUIElementTypeTextField && elementType != XCUIElementTypeSecureTextField) {
    if (!self.fb_isAccessibilityElement) {
      return NO;
    }
  }
  XCElementSnapshot *parentSnapshot = self.parent;
  while (parentSnapshot) {
    // In the scenario when table provides Search results controller, table could be marked as accessible element, even though it isn't
    // As it is highly unlikely that table view should ever be an accessibility element itself,
    // for now we work around that by skipping Table View in container checks
    if (parentSnapshot.fb_isAccessibilityElement && parentSnapshot.elementType != XCUIElementTypeTable) {
      return NO;
    }
    parentSnapshot = parentSnapshot.parent;
  }
  return YES;
}

- (BOOL)isWDAccessibilityContainer
{
  NSArray<XCElementSnapshot *> *children = self.children;
  for (XCElementSnapshot *child in children) {
    if (child.isWDAccessibilityContainer || child.fb_isAccessibilityElement) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isWDEnabled
{
  return self.isEnabled;
}

- (BOOL)isWDSelected
{
  return self.isSelected;
}

- (NSUInteger)wdIndex
{
  if (nil != self.parent) {
    for (NSUInteger index = 0; index < self.parent.children.count; ++index) {
      if ([self.parent.children objectAtIndex:index] == self) {
        return index;
      }
    }
  }

  return 0;
}

- (NSDictionary *)wdRect
{
  CGRect frame = self.wdFrame;
  return @{
    @"x": @(CGRectGetMinX(frame)),
    @"y": @(CGRectGetMinY(frame)),
    @"width": @(CGRectGetWidth(frame)),
    @"height": @(CGRectGetHeight(frame)),
  };
 }

@end
