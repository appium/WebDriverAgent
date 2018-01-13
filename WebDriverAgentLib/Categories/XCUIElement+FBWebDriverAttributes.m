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
#import "FBMacros.h"
#import "XCUIElement+FBAccessibility.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "FBElementUtils.h"

@implementation XCUIElement (WebDriverAttributesForwarding)

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  struct objc_method_description descr = protocol_getMethodDescription(@protocol(FBElement), aSelector, YES, YES);
  BOOL isWebDriverAttributesSelector = descr.name != nil;
  if(!isWebDriverAttributesSelector) {
    return nil;
  }
  if (!self.exists) {
    return [XCElementSnapshot new];
  }

  // If lastSnapshot is still missing aplication is probably not active. Returning empty element instead of crashing.
  // This will work well, if element search is requested (will not match anything) and reqesting properties values (will return nils).
  return self.fb_lastSnapshot ?: [XCElementSnapshot new];
}

@end


@implementation XCElementSnapshot (WebDriverAttributes)

static NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSMutableDictionary<NSString*, id> *> *> *fb_wdAttributesCache;

+ (void)load
{
  fb_wdAttributesCache = [NSMutableDictionary dictionary];
}

- (nullable id)fb_cachedValueWithAttributeName:(NSString *)name
{
  NSNumber *generation = [NSNumber numberWithUnsignedLongLong:self.generation];
  NSMutableDictionary<NSString *, NSMutableDictionary<NSString*, id> *> *cachedSnapshotsForGeneration = [fb_wdAttributesCache objectForKey:generation];
  if (nil == cachedSnapshotsForGeneration) {
    [fb_wdAttributesCache removeAllObjects];
    [fb_wdAttributesCache setObject:[NSMutableDictionary dictionary] forKey:generation];
  }
  NSString *selfId = [NSString stringWithFormat:@"%p", (void *)self];
  NSMutableDictionary<NSString*, id> *snapshotAttributes = [cachedSnapshotsForGeneration objectForKey:selfId];
  if (nil == snapshotAttributes) {
    [cachedSnapshotsForGeneration setObject:[NSMutableDictionary dictionary] forKey:selfId];
    return nil;
  }
  return [snapshotAttributes objectForKey:name];
}

- (id)fb_cacheValue:(nullable id)value forAttributeName:(NSString *)name
{
  NSNumber *generation = [NSNumber numberWithUnsignedLongLong:self.generation];
  NSMutableDictionary<NSString *, NSMutableDictionary<NSString*, id> *> *cachedSnapshotsForGeneration = [fb_wdAttributesCache objectForKey:generation];
  NSString *selfId = [NSString stringWithFormat:@"%p", (void *)self];
  NSMutableDictionary<NSString*, id> *snapshotAttributes = [cachedSnapshotsForGeneration objectForKey:selfId];
  [snapshotAttributes setObject:(nil == value ? [NSNull null] : (id)value) forKey:name];
  return value;
}

- (id)fb_valueForWDAttributeName:(NSString *)name
{
  return [self valueForKey:[FBElementUtils wdAttributeNameForAttributeName:name]];
}

- (NSString *)wdValue
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return cachedValue == [NSNull null] ? nil : cachedValue;
  }
  
  id (^valueGetter)(void) = ^id(void) {
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
  };
  
  return [self fb_cacheValue:valueGetter() forAttributeName:attributeName];
}

- (NSString *)wdName
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return cachedValue == [NSNull null] ? nil : cachedValue;
  }
  
  id (^nameGetter)(void) = ^id(void) {
    NSString *identifier = self.identifier;
    NSString *label = self.label;
    return FBTransferEmptyStringToNil(FBFirstNonEmptyValue(identifier, label));
  };
  
  return [self fb_cacheValue:nameGetter() forAttributeName:attributeName];
}

- (NSString *)wdLabel
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return cachedValue == [NSNull null] ? nil : cachedValue;
  }

  id (^labelGetter)(void) = ^id(void) {
    NSString *label = self.label;
    if (self.elementType == XCUIElementTypeTextField) {
      return label;
    }
    return FBTransferEmptyStringToNil(label);
  };
  
  return [self fb_cacheValue:labelGetter() forAttributeName:attributeName];
}

- (NSString *)wdType
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return cachedValue == [NSNull null] ? nil : cachedValue;
  }
  
  return [self fb_cacheValue:[FBElementTypeTransformer stringWithElementType:self.elementType] forAttributeName:attributeName];
}

- (NSUInteger)wdUID
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue integerValue];
  }
  
  return [[self fb_cacheValue:@(self.fb_uid) forAttributeName:attributeName] integerValue];
}

- (CGRect)wdFrame
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue CGRectValue];
  }
  
  return [[self fb_cacheValue:@(CGRectIntegral(self.frame)) forAttributeName:attributeName] CGRectValue];
}

- (BOOL)isWDVisible
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }
  
  return [[self fb_cacheValue:@(self.fb_isVisible) forAttributeName:attributeName] boolValue];
}

- (BOOL)isWDAccessible
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }
  
  id (^isAccessibleGetter)(void) = ^id(void) {
    XCUIElementType elementType = self.elementType;
    // Special cases:
    // Table view cell: we consider it accessible if it's container is accessible
    // Text fields: actual accessible element isn't text field itself, but nested element
    if (elementType == XCUIElementTypeCell) {
      if (!self.fb_isAccessibilityElement) {
        XCElementSnapshot *containerView = [[self children] firstObject];
        if (!containerView.fb_isAccessibilityElement) {
          return @NO;
        }
      }
    } else if (elementType != XCUIElementTypeTextField && elementType != XCUIElementTypeSecureTextField) {
      if (!self.fb_isAccessibilityElement) {
        return @NO;
      }
    }
    XCElementSnapshot *parentSnapshot = self.parent;
    while (parentSnapshot) {
      // In the scenario when table provides Search results controller, table could be marked as accessible element, even though it isn't
      // As it is highly unlikely that table view should ever be an accessibility element itself,
      // for now we work around that by skipping Table View in container checks
      if (parentSnapshot.fb_isAccessibilityElement && parentSnapshot.elementType != XCUIElementTypeTable) {
        return @NO;
      }
      parentSnapshot = parentSnapshot.parent;
    }
    return @YES;
  };
  
  return [[self fb_cacheValue:isAccessibleGetter() forAttributeName:attributeName] boolValue];
}

- (BOOL)isWDAccessibilityContainer
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }
  
  id (^isAccessibilityContainerGetter)(void) = ^id(void) {
    NSArray<XCElementSnapshot *> *children = self.children;
    for (XCElementSnapshot *child in children) {
      if (child.isWDAccessibilityContainer || child.fb_isAccessibilityElement) {
        return @YES;
      }
    }
    return @NO;
  };
  
  return [[self fb_cacheValue:isAccessibilityContainerGetter() forAttributeName:attributeName] boolValue];
}

- (BOOL)isWDEnabled
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }
  
  return [[self fb_cacheValue:@(self.isEnabled) forAttributeName:attributeName] boolValue];
}

- (NSDictionary *)wdRect
{
  NSString *attributeName = NSStringFromSelector(_cmd);
  id cachedValue = [self fb_cachedValueWithAttributeName:attributeName];
  if (nil != cachedValue) {
    return cachedValue == [NSNull null] ? nil : cachedValue;
  }
  
  id (^rectGetter)(void) = ^id(void) {
    CGRect frame = self.wdFrame;
    return @{
      @"x": @(CGRectGetMinX(frame)),
      @"y": @(CGRectGetMinY(frame)),
      @"width": @(CGRectGetWidth(frame)),
      @"height": @(CGRectGetHeight(frame)),
    };
  };
  
  return [self fb_cacheValue:rectGetter() forAttributeName:attributeName];
}

@end
