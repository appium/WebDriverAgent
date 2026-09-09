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
 actions use. The offset is normalized against the element's wdFrame (the same
 WDA-reported coordinate space pointsOffset itself is measured in) instead of being
 passed through as a raw points offset, which XCTest never rescales for
 compatibility-mode windows (see appium/appium#16185).

 @param element the element to anchor the coordinate to
 @param anchorOffset normalized offset of the anchor point within the element's wdFrame
 @param pointsOffset raw points offset from the anchor point, in wdFrame's coordinate space
 @param error populated if the element's frame is empty (not visible on the screen)
 @return the resulting coordinate, or nil if the element's frame is empty
 */
XCUICoordinate * _Nullable FBCoordinateWithAnchorOffset(XCUIElement *element,
                                                         CGVector anchorOffset,
                                                         CGVector pointsOffset,
                                                         NSError **error);
#endif

/*!
 Computes the normalized (0.0-1.0) start/end offsets of a scroll drag gesture whose
 touch-down/up points fall within scrollingFrame, expressed relative to anchorFrame -
 the coordinate space the resulting offsets get resolved against (e.g. via
 -[XCUIElement coordinateWithNormalizedOffset:]). scrollingFrame and anchorFrame are
 usually the same rect, but scrollingFrame may be clipped to a visible sub-region, and/or
 the two may come from frame sources XCTest doesn't keep in sync (see appium/appium#16185)
 - passing mismatched frames here reproduces that bug rather than fixing it.

 @param scrollingFrame the (possibly clipped) frame to compute the touch-down/up points within
 @param anchorFrame the frame startOffset/endOffset get normalized against
 @param proportion normalized touch-down position within scrollingFrame, e.g. from
        -fb_normalizedHitPointOffsetForScrollingVector:
 @param vector the scroll vector, in scrollingFrame's coordinate space
 @param startOffset populated with the normalized start offset; untouched if NO is returned
 @param endOffset populated with the normalized end offset; untouched if NO is returned
 @return NO if either frame is empty
 */
BOOL FBScrollGestureOffsets(CGRect scrollingFrame,
                            CGRect anchorFrame,
                            CGVector proportion,
                            CGVector vector,
                            CGVector *startOffset,
                            CGVector *endOffset);

NS_ASSUME_NONNULL_END
