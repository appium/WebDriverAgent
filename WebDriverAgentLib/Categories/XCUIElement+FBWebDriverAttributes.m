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

#define BROKEN_RECT CGRectMake(-1, -1, 0, 0)

@implementation XCUIElement (WebDriverAttributesForwarding)

- (id<FBXCElementSnapshot>)fb_snapshotForAttributeName:(NSString *)name
{
  // These attributes are special, because we can only retrieve them from
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
  CGRect frame = self.frame;
  // It is mandatory to replace all Infinity values with numbers to avoid JSON parsing
  // exceptions like https://github.com/facebook/WebDriverAgent/issues/639#issuecomment-314421206
  // caused by broken element dimensions returned by XCTest
  return (isinf(frame.size.width) || isinf(frame.size.height)
          || isinf(frame.origin.x) || isinf(frame.origin.y))
    ? CGRectIntegral(BROKEN_RECT)
    : CGRectIntegral(frame);
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
    if ([FBXCElementSnapshotWrapper ensureWrapped:parentSnapshot].fb_isAccessibilityElement
        && parentSnapshot.elementType != XCUIElementTypeTable) {
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
