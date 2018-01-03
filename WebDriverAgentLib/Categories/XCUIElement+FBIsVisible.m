/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBIsVisible.h"

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBElementUtils.h"
#import "FBMathUtils.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCAccessibilityElement.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot+FBHitPoint.h"

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

- (BOOL)fb_isVisible
{
  CGRect frame = self.frame;
  if (CGRectIsEmpty(frame)) {
    return NO;
  }
  
  if ([FBConfiguration shouldUseTestManagerForVisibilityDetection]) {
    return [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsVisibleAttribute] boolValue];
  }
  
  NSMutableArray<XCElementSnapshot *> *parentsChain = [NSMutableArray array];
  XCElementSnapshot *parent = self.parent;
  while (parent) {
    [parentsChain addObject:parent];
    parent = parent.parent;
  }
  XCElementSnapshot *parentWindow = nil;
  for (parent in parentsChain) {
    if (parent.elementType == XCUIElementTypeWindow) {
      parentWindow = parent;
      break;
    }
  }
  CGRect appFrame = [self fb_rootElement].frame;
  if (nil == parentWindow) {
    return CGRectContainsPoint(appFrame, self.fb_hitPoint);
  }
  CGRect rectInContainer = [self fb_frameInContainer:parentWindow hierarchyIntersection:nil];
  if (CGRectIsEmpty(rectInContainer)) {
    return NO;
  }
  if (self.elementType == XCUIElementTypeCell) {
    // Special case - detect visibility based on gesture recognizer presence
    return self.parent.fb_isVisible;
  }
  CGPoint visibleRectCenter = CGPointMake(frame.origin.x + frame.size.width / 2, frame.origin.y + frame.size.height / 2);
  if (!CGRectEqualToRect(appFrame, nil == parentWindow ? frame : parentWindow.frame)) {
    visibleRectCenter = FBInvertPointForApplication(visibleRectCenter, appFrame.size, FBApplication.fb_activeApplication.interfaceOrientation);
  }
  XCAccessibilityElement *match = [FBXCTestDaemonsProxy accessibilityElementAtPoint:visibleRectCenter error:NULL];
  if (nil == match) {
    return NO;
  }
  NSUInteger matchUID = [FBElementUtils uidWithAccessibilityElement:match];
  if (self.fb_uid == matchUID) {
    return YES;
  }
  for (XCElementSnapshot *descendant in self._allDescendants) {
    if (matchUID == [FBElementUtils uidWithAccessibilityElement:descendant.accessibilityElement]) {
      return YES;
    }
  }
  // Special case - detect visibility based on gesture recognizer presence
  XCElementSnapshot *parentCell = nil;
  for (parent in parentsChain) {
    if (parent.elementType == XCUIElementTypeCell) {
      parentCell = parent;
      break;
    }
  }
  if (nil == parentCell) {
    return NO;
  }
  for (parent in parentsChain) {
    if (matchUID == [FBElementUtils uidWithAccessibilityElement:parent.accessibilityElement]) {
      return YES;
    }
    if (parent == parentCell) {
      break;
    }
  }
  return NO;
}

@end
