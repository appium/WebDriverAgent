/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUICoordinate+FBFix.h"

#import "XCUICoordinate.h"
#import "XCUIElement+FBUtilities.h"
#import "XCElementSnapshot+FBHitPoint.h"

# if !TARGET_OS_TV
@implementation XCUICoordinate (FBFix)

- (CGPoint)fb_screenPoint
{
  CGPoint referencePoint = CGPointMake(0, 0);
  NSValue *referencedElementFrame = nil;
  if (self.element) {
    CGRect elementFrame = self.element.frame;
    if (self.referencedElement == self.element) {
      referencedElementFrame = [NSValue valueWithCGRect:elementFrame];
    }
    referencePoint = CGPointMake(
      CGRectGetMinX(elementFrame) + CGRectGetWidth(elementFrame) * self.normalizedOffset.dx,
      CGRectGetMinY(elementFrame) + CGRectGetHeight(elementFrame) * self.normalizedOffset.dy);
  } else if (self.coordinate) {
    referencePoint = self.coordinate.fb_screenPoint;
  }

  CGPoint screenPoint = CGPointMake(
    referencePoint.x + self.pointsOffset.dx,
    referencePoint.y + self.pointsOffset.dy);
  if (nil == referencedElementFrame) {
    referencedElementFrame = [NSValue valueWithCGRect:self.referencedElement.frame];
  }
  return CGPointMake(
    MIN(CGRectGetMaxX(referencedElementFrame.CGRectValue), screenPoint.x),
    MIN(CGRectGetMaxY(referencedElementFrame.CGRectValue), screenPoint.y));
}

@end
#endif
