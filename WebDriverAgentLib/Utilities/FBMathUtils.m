/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBMathUtils.h"

#import "FBMacros.h"

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

#if !TARGET_OS_TV

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
#endif
