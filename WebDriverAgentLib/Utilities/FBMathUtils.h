/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

@class XCUIApplication;
@class XCUICoordinate;
@class XCUIElement;

NS_ASSUME_NONNULL_BEGIN

extern CGFloat FBDefaultFrameFuzzyThreshold;

/*! Returns center point of given rect */
CGPoint FBRectGetCenter(CGRect rect);

/*! Returns whether floatss are equal within given threshold */
BOOL FBFloatFuzzyEqualToFloat(CGFloat float1, CGFloat float2, CGFloat threshold);

/*! Returns whether points are equal within given threshold */
BOOL FBPointFuzzyEqualToPoint(CGPoint point1, CGPoint point2, CGFloat threshold);

/*! Returns whether vectors are equal within given threshold */
BOOL FBVectorFuzzyEqualToVector(CGVector a, CGVector b, CGFloat threshold);

/*! Returns whether size are equal within given threshold */
BOOL FBSizeFuzzyEqualToSize(CGSize size1, CGSize size2, CGFloat threshold);

/*! Returns whether rect are equal within given threshold */
BOOL FBRectFuzzyEqualToRect(CGRect rect1, CGRect rect2, CGFloat threshold);

#if !TARGET_OS_TV && !TARGET_OS_WATCH
/*! Inverts size if necessary to match current screen orientation */
CGSize FBAdjustDimensionsForApplication(CGSize actualSize, UIInterfaceOrientation orientation);
#endif

#if !TARGET_OS_TV
/*!
 Builds a coordinate for the given element from a raw points offset measured from a
 normalized anchor point within the element's own frame - e.g. (0, 0) for an offset
 relative to the top-left corner, (0.5, 0.5) for one relative to the center, as W3C
 actions use. The offset is normalized against the element's frame instead of being
 passed through as a raw points offset, which XCTest never rescales for
 compatibility-mode windows (see appium/appium#16185).

 @param element the element to anchor the coordinate to
 @param anchorOffset normalized offset of the anchor point within the element's frame
 @param pointsOffset raw points offset from the anchor point
 @param error populated if the element's frame is empty (not visible on the screen)
 @return the resulting coordinate, or nil if the element's frame is empty
 */
XCUICoordinate * _Nullable FBCoordinateWithAnchorOffset(XCUIElement *element,
                                                         CGVector anchorOffset,
                                                         CGVector pointsOffset,
                                                         NSError **error);
#endif

NS_ASSUME_NONNULL_END
