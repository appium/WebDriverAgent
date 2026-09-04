/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMathUtils.h"

#import "FBErrorBuilder.h"
#import "FBMacros.h"
#import "XCUICoordinate.h"
#import "XCUIElement.h"

CGFloat FBDefaultFrameFuzzyThreshold = 2.0;

CGPoint FBRectGetCenter(CGRect rect)
{
  return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

BOOL FBFloatFuzzyEqualToFloat(CGFloat float1, CGFloat float2, CGFloat threshold)
{
  return (fabs(float1 - float2) <= threshold);
}

BOOL FBVectorFuzzyEqualToVector(CGVector a, CGVector b, CGFloat threshold)
{
  return FBFloatFuzzyEqualToFloat(a.dx, b.dx, threshold) && FBFloatFuzzyEqualToFloat(a.dy, b.dy, threshold);
}

BOOL FBPointFuzzyEqualToPoint(CGPoint point1, CGPoint point2, CGFloat threshold)
{
  return FBFloatFuzzyEqualToFloat(point1.x, point2.x, threshold) && FBFloatFuzzyEqualToFloat(point1.y, point2.y, threshold);
}

BOOL FBSizeFuzzyEqualToSize(CGSize size1, CGSize size2, CGFloat threshold)
{
  return FBFloatFuzzyEqualToFloat(size1.width, size2.width, threshold) && FBFloatFuzzyEqualToFloat(size1.height, size2.height, threshold);
}

BOOL FBRectFuzzyEqualToRect(CGRect rect1, CGRect rect2, CGFloat threshold)
{
  return
  FBPointFuzzyEqualToPoint(FBRectGetCenter(rect1), FBRectGetCenter(rect2), threshold) &&
  FBSizeFuzzyEqualToSize(rect1.size, rect2.size, threshold);
}

#if !TARGET_OS_TV && !TARGET_OS_WATCH

CGSize FBAdjustDimensionsForApplication(CGSize actualSize, UIInterfaceOrientation orientation)
{
  if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
    /*
     There is an XCTest bug that application.frame property returns exchanged dimensions for landscape mode.
     This verification is just to make sure the bug is still there (since height is never greater than width in landscape) 
     and to make it still working properly after XCTest itself starts to respect landscape mode.
     */
    if (actualSize.height > actualSize.width) {
      return CGSizeMake(actualSize.height, actualSize.width);
    }
  }
  return actualSize;
}

XCUICoordinate *FBCoordinateWithAnchorOffset(XCUIElement *element,
                                              CGVector anchorOffset,
                                              CGVector pointsOffset,
                                              NSError **error)
{
  // Read the frame once: checking CGRectIsEmpty and then re-reading element.frame for the
  // divide below are two separate live round-trips, which a frame could collapse between.
  CGRect frame = element.frame;
  if (CGRectIsEmpty(frame)) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"The element '%@' is not visible on the screen and thus is not interactable", element.description]
     buildError:error];
    return nil;
  }
  CGVector normalizedOffset = CGVectorMake(anchorOffset.dx + pointsOffset.dx / frame.size.width,
                                           anchorOffset.dy + pointsOffset.dy / frame.size.height);
  return [element coordinateWithNormalizedOffset:normalizedOffset];
}
#endif
