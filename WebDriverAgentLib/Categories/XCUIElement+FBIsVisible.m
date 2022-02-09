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
#import "FBActiveAppDetectionPoint.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "XCAccessibilityElement+FBComparison.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCElementSnapshot+FBHitPoint.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBUID.h"
#import "XCTestPrivateSymbols.h"

@implementation XCUIElement (FBIsVisible)

- (BOOL)fb_isVisible
{
  return [self fb_snapshotWithAttributes:@[FB_XCAXAIsVisibleAttributeName]
                                maxDepth:@1].fb_isVisible;
}

@end

@implementation XCElementSnapshot (FBIsVisible)

- (NSString *)fb_uniqId
{
  return self.fb_uid ?: [NSString stringWithFormat:@"%p", (void *)self];
}

- (nullable NSNumber *)fb_cachedVisibilityValue
{
  NSMutableDictionary *cache = FBSession.activeSession.elementsVisibilityCache;
  if (nil == cache) {
    return nil;
  }

  NSDictionary<NSString *, NSNumber *> *result = [cache objectForKey:@(self.generation)];
  if (nil == result) {
    // There is no need to keep the cached data for the previous generations
    [cache removeAllObjects];
    [cache setObject:[NSMutableDictionary dictionary] forKey:@(self.generation)];
    return nil;
  }
  return [result objectForKey:self.fb_uniqId];
}

- (BOOL)fb_cacheVisibilityWithValue:(BOOL)isVisible
                       forAncestors:(nullable NSArray<XCElementSnapshot *> *)ancestors
{
  NSMutableDictionary *cache = FBSession.activeSession.elementsVisibilityCache;
  if (nil == cache) {
    return isVisible;
  }
  NSMutableDictionary<NSString *, NSNumber *> *destination = [cache objectForKey:@(self.generation)];
  if (nil == destination) {
    return isVisible;
  }

  NSNumber *visibleObj = [NSNumber numberWithBool:isVisible];
  [destination setObject:visibleObj forKey:self.fb_uniqId];
  if (isVisible && nil != ancestors) {
    // if an element is visible then all its ancestors must be visible as well
    for (XCElementSnapshot *ancestor in ancestors) {
      NSString *ancestorId = ancestor.fb_uniqId;
      if (nil == [destination objectForKey:ancestorId]) {
        [destination setObject:visibleObj forKey:ancestorId];
      }
    }
  }
  return isVisible;
}

- (CGRect)fb_frameInContainer:(XCElementSnapshot *)container
        hierarchyIntersection:(nullable NSValue *)intersectionRectange
{
  CGRect currentRectangle = nil == intersectionRectange ? self.frame : [intersectionRectange CGRectValue];
  XCElementSnapshot *parent = self.parent;
  CGRect parentFrame = parent.frame;
  CGRect containerFrame = container.frame;
  if (CGSizeEqualToSize(parentFrame.size, CGSizeZero) &&
      CGPointEqualToPoint(parentFrame.origin, CGPointZero)) {
    // Special case (or XCTest bug). Shift the origin and return immediately after shift
    XCElementSnapshot *nextParent = parent.parent;
    BOOL isGrandparent = YES;
    while (nextParent && nextParent != container) {
      CGRect nextParentFrame = nextParent.frame;
      if (isGrandparent &&
          CGSizeEqualToSize(nextParentFrame.size, CGSizeZero) &&
          CGPointEqualToPoint(nextParentFrame.origin, CGPointZero)) {
        // Double zero-size container inclusion means that element coordinates are absolute
        return CGRectIntersection(currentRectangle, containerFrame);
      }
      isGrandparent = NO;
      if (!CGPointEqualToPoint(nextParentFrame.origin, CGPointZero)) {
        currentRectangle.origin.x += nextParentFrame.origin.x;
        currentRectangle.origin.y += nextParentFrame.origin.y;
        return CGRectIntersection(currentRectangle, containerFrame);
      }
      nextParent = nextParent.parent;
    }
    return CGRectIntersection(currentRectangle, containerFrame);
  }
  // Skip parent containers if they are outside of the viewport
  CGRect intersectionWithParent = CGRectIntersectsRect(parentFrame, containerFrame) || parent.elementType != XCUIElementTypeOther
    ? CGRectIntersection(currentRectangle, parentFrame)
    : currentRectangle;
  if (CGRectIsEmpty(intersectionWithParent) &&
      parent != container &&
      self.elementType == XCUIElementTypeOther) {
    // Special case (or XCTest bug). Shift the origin
    if (CGSizeEqualToSize(parentFrame.size, containerFrame.size) ||
        // The size might be inverted in landscape
        CGSizeEqualToSize(parentFrame.size, CGSizeMake(containerFrame.size.height, containerFrame.size.width)) ||
        CGSizeEqualToSize(self.frame.size, CGSizeZero)) {
      // Covers ActivityListView and RemoteBridgeView cases
      currentRectangle.origin.x += parentFrame.origin.x;
      currentRectangle.origin.y += parentFrame.origin.y;
      return CGRectIntersection(currentRectangle, containerFrame);
    }
  }
  if (CGRectIsEmpty(intersectionWithParent) || parent == container) {
    return intersectionWithParent;
  }
  return [parent fb_frameInContainer:container hierarchyIntersection:[NSValue valueWithCGRect:intersectionWithParent]];
}

- (BOOL)fb_hasAnyVisibleLeafs
{
  NSArray<XCElementSnapshot *> *children = self.children;
  if (0 == children.count) {
    return self.fb_isVisible;
  }

  for (XCElementSnapshot *child in children) {
    if (child.fb_hasAnyVisibleLeafs) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)fb_isVisible
{
  NSNumber *isVisible = self.additionalAttributes[FB_XCAXAIsVisibleAttribute];
  if (isVisible != nil) {
    return isVisible.boolValue;
  }
  
  NSNumber *cachedValue = [self fb_cachedVisibilityValue];
  if (nil != cachedValue) {
    return [cachedValue boolValue];
  }

  CGRect selfFrame = self.frame;
  if (CGRectIsEmpty(selfFrame)) {
    return [self fb_cacheVisibilityWithValue:NO forAncestors:nil];
  }

  NSArray<XCElementSnapshot *> *ancestors = self.fb_ancestors;
  if ([FBConfiguration shouldUseTestManagerForVisibilityDetection]) {
    BOOL visibleAttrValue = [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsVisibleAttributeName] boolValue];
    return [self fb_cacheVisibilityWithValue:visibleAttrValue forAncestors:ancestors];
  }

  XCElementSnapshot *parentWindow = ancestors.count > 1 ? [ancestors objectAtIndex:ancestors.count - 2] : nil;
  CGRect visibleRect = selfFrame;
  if (nil != parentWindow) {
    visibleRect = [self fb_frameInContainer:parentWindow hierarchyIntersection:nil];
  }
  if (CGRectIsEmpty(visibleRect)) {
    return [self fb_cacheVisibilityWithValue:NO forAncestors:ancestors];
  }
  CGPoint midPoint = CGPointMake(visibleRect.origin.x + visibleRect.size.width / 2,
                                 visibleRect.origin.y + visibleRect.size.height / 2);
#if !TARGET_OS_TV // TV has no orientation, so it does not need to coordinate
  XCElementSnapshot *appElement = ancestors.count > 0 ? [ancestors lastObject] : self;
  CGRect appFrame = appElement.frame;
  CGRect windowFrame = nil == parentWindow ? selfFrame : parentWindow.frame;
  if ((appFrame.size.height > appFrame.size.width && windowFrame.size.height < windowFrame.size.width) ||
      (appFrame.size.height < appFrame.size.width && windowFrame.size.height > windowFrame.size.width)) {
    // This is the indication of the fact that transformation is broken and coordinates should be
    // recalculated manually.
    // However, upside-down case cannot be covered this way, which is not important for Appium
    midPoint = FBInvertPointForApplication(midPoint, appFrame.size, FBApplication.fb_activeApplication.interfaceOrientation);
  }
#endif
  XCAccessibilityElement *hitElement = [FBActiveAppDetectionPoint axElementWithPoint:midPoint];
  if (nil != hitElement) {
    if ([self.accessibilityElement fb_isEqualToElement:hitElement]) {
      return [self fb_cacheVisibilityWithValue:YES forAncestors:ancestors];
    }
    for (XCElementSnapshot *ancestor in ancestors) {
      if ([hitElement fb_isEqualToElement:ancestor.accessibilityElement]) {
        return [self fb_cacheVisibilityWithValue:YES forAncestors:ancestors];
      }
    }
  }
  if (self.children.count > 0) {
    if (nil != hitElement) {
      for (XCElementSnapshot *descendant in self._allDescendants) {
        if ([hitElement fb_isEqualToElement:descendant.accessibilityElement]) {
          return [self fb_cacheVisibilityWithValue:YES forAncestors:descendant.fb_ancestors];
        }
      }
    }
    if (self.fb_hasAnyVisibleLeafs) {
      return [self fb_cacheVisibilityWithValue:YES forAncestors:ancestors];
    }
  } else if (nil == hitElement) {
    // Sometimes XCTest returns nil for leaf elements hit test even if such elements are hittable
    // Assume such elements are visible if their rectInContainer is visible
    return [self fb_cacheVisibilityWithValue:YES forAncestors:ancestors];
  }
  return [self fb_cacheVisibilityWithValue:NO forAncestors:ancestors];
}

@end
