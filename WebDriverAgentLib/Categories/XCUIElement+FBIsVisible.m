/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBIsVisible.h"

#import "FBConfiguration.h"
#import "FBElementUtils.h"
#import "FBMathUtils.h"
#import "FBXCodeCompatibility.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestPrivateSymbols.h"

@implementation XCUIElement (FBIsVisible)

- (BOOL)fb_isVisible
{
  return self.fb_lastSnapshot.fb_isVisible;
}

- (CGRect)fb_frameInWindow
{
  return self.fb_lastSnapshot.fb_frameInWindow;
}

@end

@implementation XCElementSnapshot (FBIsVisible)

static NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *fb_generationsCache;

+ (void)load
{
  fb_generationsCache = [NSMutableDictionary dictionary];
}

- (nullable NSNumber *)fb_cachedVisibilityValue
{
  unsigned long long generation = self.generation;
  NSDictionary<NSString *, NSNumber *> *result = [fb_generationsCache objectForKey:@(generation)];
  if (nil == result) {
    // There is no need to keep the cached data for the previous generations
    [fb_generationsCache removeAllObjects];
    [fb_generationsCache setObject:[NSMutableDictionary dictionary] forKey:@(generation)];
    return nil;
  }
  return [result objectForKey:[NSString stringWithFormat:@"%p", (void *)self]];
}

- (BOOL)fb_cacheVisibilityWithValue:(BOOL)isVisible
{
  NSMutableDictionary<NSString *, NSNumber *> *destination = [fb_generationsCache objectForKey:@(self.generation)];
  [destination setObject:@(isVisible) forKey:[NSString stringWithFormat:@"%p", (void *)self]];
  return isVisible;
}

- (CGRect)fb_frameInContainer:(XCElementSnapshot *)container hierarchyIntersection:(nullable NSValue *)intersectionRectange
{
  CGRect currentRectangle = nil == intersectionRectange ? self.frame : [intersectionRectange CGRectValue];
  XCElementSnapshot *parent = self.parent;
  CGRect intersectionWithParent = CGRectIntersection(currentRectangle, parent.frame);
  if (CGRectIsEmpty(intersectionWithParent) || parent == container) {
    return intersectionWithParent;
  }
  return [parent fb_frameInContainer:container hierarchyIntersection:[NSValue valueWithCGRect:intersectionWithParent]];
}

- (CGRect)fb_frameInWindow
{
  XCElementSnapshot *parentWindow = [self fb_parentMatchingType:XCUIElementTypeWindow];
  if (nil != parentWindow) {
    return [self fb_frameInContainer:parentWindow hierarchyIntersection:nil];
  }
  return self.frame;
}

- (BOOL)fb_hasAnyVisibleLeafs
{
  NSArray<XCElementSnapshot *> *children = self.children;
  if (0 == children.count) {
    return self.fb_isVisible;
  }
  
  for (XCElementSnapshot *child in children) {
    if ([child fb_hasAnyVisibleLeafs]) {
      return YES;
    }
  }
  
  return NO;
}

- (BOOL)fb_isVisible
{
  NSNumber *cachedValue = [self fb_cachedVisibilityValue];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }
  
  CGRect frame = self.frame;
  if (CGRectIsEmpty(frame)) {
    return [self fb_cacheVisibilityWithValue:NO];
  }
  
  if ([FBConfiguration shouldUseTestManagerForVisibilityDetection]) {
    BOOL isVisible = [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsVisibleAttribute] boolValue];
    return [self fb_cacheVisibilityWithValue:isVisible];
  }
  
  XCElementSnapshot *parentWindow = nil;
  NSMutableArray<XCElementSnapshot *> *ancestorsUntilWindow = [NSMutableArray array];
  XCElementSnapshot *parent = self.parent;
  while (parent) {
    XCUIElementType type = parent.elementType;
    if (type == XCUIElementTypeWindow) {
      parentWindow = parent;
      break;
    }
    [ancestorsUntilWindow addObject:parent];
    parent = parent.parent;
  }
  if (nil == parentWindow) {
    [ancestorsUntilWindow removeAllObjects];
  }
  
  CGRect appFrame = [self fb_rootElement].frame;
  CGRect rectInContainer = nil == parentWindow ? self.frame : [self fb_frameInContainer:parentWindow hierarchyIntersection:nil];
  if (CGRectIsEmpty(rectInContainer)) {
    return [self fb_cacheVisibilityWithValue:NO];
  }
  if (self.children.count > 0 && self.fb_hasAnyVisibleLeafs) {
    return [self fb_cacheVisibilityWithValue:YES];
  }
  CGPoint midPoint = CGPointMake(rectInContainer.origin.x + rectInContainer.size.width / 2,
                                 rectInContainer.origin.y + rectInContainer.size.height / 2);
  CGRect parentWindowFrame = parentWindow.frame;
  if ((appFrame.size.height > appFrame.size.width && parentWindowFrame.size.height < parentWindowFrame.size.width) ||
      (appFrame.size.height < appFrame.size.width && parentWindowFrame.size.height > parentWindowFrame.size.width)) {
    // This is the indication of the fact that transformation is broken and coordinates should be
    // recalculated manually.
    // However, upside-down case cannot be covered this way, which is not important for Appium
    midPoint = FBInvertPointForApplication(midPoint, appFrame.size, FBApplication.fb_activeApplication.interfaceOrientation);
  }
  XCElementSnapshot *hitElement = [self hitTest:midPoint];
  if (nil != hitElement && (self == hitElement || [ancestorsUntilWindow containsObject:hitElement])) {
    return [self fb_cacheVisibilityWithValue:YES];
  }
  return [self fb_cacheVisibilityWithValue:NO];
}

@end

