/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBWebDriverAttributes.h"

#import "FBElementTypeTransformer.h"
#import "FBElementHelpers.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBXCElementSnapshotWrapper.h"
#import "XCUIElement+FBAccessibility.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "FBElementUtils.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIHitPointResult.h"
#import "XCUIApplication+FBHelpers.h"

#define BROKEN_RECT CGRectMake(-1, -1, 0, 0)

@implementation XCUIElement (WebDriverAttributesForwarding)

- (id<FBXCElementSnapshot>)fb_snapshotForAttributeName:(NSString *)name
{
  // https://github.com/appium/appium-xcuitest-driver/pull/2565
  if ([name isEqualToString:FBStringify(XCUIElement, isWDHittable)]) {
    return [self fb_nativeSnapshot];
  }
  // https://github.com/appium/appium-xcuitest-driver/issues/2552
  BOOL isValueRequest = [name isEqualToString:FBStringify(XCUIElement, wdValue)];
  if ([self isKindOfClass:XCUIApplication.class] && !isValueRequest) {
    return [self fb_standardSnapshot];
  }
  BOOL isCustomSnapshot = [name isEqualToString:FBStringify(XCUIElement, isWDAccessible)]
    || [name isEqualToString:FBStringify(XCUIElement, isWDAccessibilityContainer)]
    || [name isEqualToString:FBStringify(XCUIElement, wdIndex)]
    || isValueRequest;
  return isCustomSnapshot ? [self fb_customSnapshot] : [self fb_standardSnapshot];
}

- (id)fb_valueForWDAttributeName:(NSString *)name
{
  NSString *wdAttributeName = [FBElementUtils wdAttributeNameForAttributeName:name];
  id<FBXCElementSnapshot> snapshot = [self fb_snapshotForAttributeName:wdAttributeName];
  return [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_valueForWDAttributeName:name];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  static dispatch_once_t onceToken;
  static NSSet<NSString *> *fbElementAttributeNames;
  dispatch_once(&onceToken, ^{
    fbElementAttributeNames = [FBElementUtils selectorNamesWithProtocol:@protocol(FBElement)];
  });
  NSString* attributeName = NSStringFromSelector(aSelector);
  return [fbElementAttributeNames containsObject:attributeName]
    ? [FBXCElementSnapshotWrapper ensureWrapped:[self fb_snapshotForAttributeName:attributeName]]
    : nil;
}

@end


@implementation FBXCElementSnapshotWrapper (WebDriverAttributes)

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
  } else if (FBDoesElementSupportInnerText(elementType)) {
    NSString *placeholderValue = self.placeholderValue;
    value = FBFirstNonEmptyValue(value, placeholderValue);
  }
  value = FBTransferEmptyStringToNil(value);
  if (value) {
    value = [NSString stringWithFormat:@"%@", value];
  }
  return value;
}

+ (NSString *)wdNameWithSnapshot:(id<FBXCElementSnapshot>)snapshot
{
  NSString *identifier = snapshot.identifier;
  if (nil != identifier && identifier.length != 0) {
    return identifier;
  }
  NSString *label = snapshot.label;
  return FBTransferEmptyStringToNil(label);
}

- (NSString *)wdName
{
  return [self.class wdNameWithSnapshot:self.snapshot];
}

- (NSString *)wdLabel
{
  XCUIElementType elementType = self.elementType;
  return (elementType == XCUIElementTypeTextField
          || elementType == XCUIElementTypeSecureTextField)
    ? self.label
    : FBTransferEmptyStringToNil(self.label);
}

- (NSString *)wdPlaceholderValue
{
  return FBDoesElementSupportInnerText(self.elementType)
    ? self.placeholderValue
    : FBTransferEmptyStringToNil(self.placeholderValue);
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
  CGRect frame = self.frame;
  // It is mandatory to replace all Infinity values with numbers to avoid JSON parsing
  // exceptions like https://github.com/facebook/WebDriverAgent/issues/639#issuecomment-314421206
  // caused by broken element dimensions returned by XCTest
  return (isinf(frame.size.width) || isinf(frame.size.height)
          || isinf(frame.origin.x) || isinf(frame.origin.y))
    ? CGRectIntegral(BROKEN_RECT)
    : CGRectIntegral(frame);
}

- (CGRect)wdNativeFrame
{
  // To avoid confusion regarding the frame returned by `wdFrame`,
  // the current property is provided to represent the element's
  // actual rendered frame.
  return self.frame;
}

- (BOOL)isWDVisible
{
  return self.fb_isVisible;
}

- (BOOL)isWDFocused
{
  return self.hasFocus;
}

- (BOOL)isWDAccessible
{
  XCUIElementType elementType = self.elementType;
  // Special cases:
  // Table view cell: we consider it accessible if it's container is accessible
  // Text fields: actual accessible element isn't text field itself, but nested element
  if (elementType == XCUIElementTypeCell) {
    if (!self.fb_isAccessibilityElement) {
      id<FBXCElementSnapshot> containerView = [[self children] firstObject];
      if (![FBXCElementSnapshotWrapper ensureWrapped:containerView].fb_isAccessibilityElement) {
        return NO;
      }
    }
  } else if (elementType != XCUIElementTypeTextField && elementType != XCUIElementTypeSecureTextField) {
    if (!self.fb_isAccessibilityElement) {
      return NO;
    }
  }
  id<FBXCElementSnapshot> parentSnapshot = self.parent;
  while (parentSnapshot) {
    // In the scenario when table provides Search results controller, table could be marked as accessible element, even though it isn't
    // As it is highly unlikely that table view should ever be an accessibility element itself,
    // for now we work around that by skipping Table View in container checks
    if (parentSnapshot.elementType != XCUIElementTypeTable
        && [FBXCElementSnapshotWrapper ensureWrapped:parentSnapshot].fb_isAccessibilityElement) {
      return NO;
    }
    parentSnapshot = parentSnapshot.parent;
  }
  return YES;
}

- (BOOL)isWDAccessibilityContainer
{
  NSArray<id<FBXCElementSnapshot>> *children = self.children;
  for (id<FBXCElementSnapshot> child in children) {
    FBXCElementSnapshotWrapper *wrappedChild = [FBXCElementSnapshotWrapper ensureWrapped:child];
    if (wrappedChild.isWDAccessibilityContainer || wrappedChild.fb_isAccessibilityElement) {
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
      if ([self.parent.children objectAtIndex:index] == self.snapshot) {
        return index;
      }
    }
  }

  return 0;
}

- (BOOL)isWDHittable
{
  XCUIHitPointResult *result = [self hitPoint:nil];
  return nil == result ? NO : result.hittable;
}

- (BOOL)isWDResolvedHittable
{
  // Snapshot-based estimation of XCUIElement.hittable using accessibility, visibility, and hit point.
  // Does not rely on live XCUIElement resolution.
  // See discussion: https://github.com/appium/WebDriverAgent/pull/1021
  return self.isWDAccessible && self.isWDHittable && self.isWDVisible;
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
