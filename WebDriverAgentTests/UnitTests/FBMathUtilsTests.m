/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBMathUtils.h"

@interface FBMathUtilsTests : XCTestCase
@end

@implementation FBMathUtilsTests

- (void)testGetCenter
{
  XCTAssertTrue(CGPointEqualToPoint(FBRectGetCenter(CGRectMake(0, 0, 4, 4)), CGPointMake(2, 2)));
  XCTAssertTrue(CGPointEqualToPoint(FBRectGetCenter(CGRectMake(1, 1, 4, 4)), CGPointMake(3, 3)));
  XCTAssertTrue(CGPointEqualToPoint(FBRectGetCenter(CGRectMake(1, 3, 6, 14)), CGPointMake(4, 10)));
}

- (void)testFuzzyEqualFloats
{
  XCTAssertTrue(FBFloatFuzzyEqualToFloat(0, 0, 0));
  XCTAssertTrue(FBFloatFuzzyEqualToFloat(0.5, 0.6, 0.2));
  XCTAssertTrue(FBFloatFuzzyEqualToFloat(0.6, 0.5, 0.2));
  XCTAssertTrue(FBFloatFuzzyEqualToFloat(0.5, 0.6, 0.10001));
}

- (void)testFuzzyNotEqualFloats
{
  XCTAssertFalse(FBFloatFuzzyEqualToFloat(0, 1, 0));
  XCTAssertFalse(FBFloatFuzzyEqualToFloat(1, 0, 0));
  XCTAssertFalse(FBFloatFuzzyEqualToFloat(0.5, 0.6, 0.05));
  XCTAssertFalse(FBFloatFuzzyEqualToFloat(0.6, 0.5, 0.05));
}

- (void)testFuzzyEqualPoints
{
  CGPoint referencePoint = CGPointMake(3, 3);
  XCTAssertTrue(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(3, 3), 2));
  XCTAssertTrue(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(3, 4), 2));
  XCTAssertTrue(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(4, 3), 2));
}

- (void)testFuzzyNotEqualPoints
{
  CGPoint referencePoint = CGPointMake(3, 3);
  XCTAssertFalse(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(5, 5), 1));
  XCTAssertFalse(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(3, 5), 1));
  XCTAssertFalse(FBPointFuzzyEqualToPoint(referencePoint, CGPointMake(5, 3), 1));
}

- (void)testFuzzyEqualSizes
{
  CGSize referenceSize = CGSizeMake(3, 3);
  XCTAssertTrue(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(3, 3), 2));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(3, 4), 2));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(4, 3), 2));
}

- (void)testFuzzyNotEqualSizes
{
  CGSize referenceSize = CGSizeMake(3, 3);
  XCTAssertFalse(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(5, 5), 1));
  XCTAssertFalse(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(3, 5), 1));
  XCTAssertFalse(FBSizeFuzzyEqualToSize(referenceSize, CGSizeMake(5, 3), 1));
}

- (void)testFuzzyEqualRects
{
  CGRect referenceRect = CGRectMake(3, 3, 3, 3);
  XCTAssertTrue(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 3, 3, 3), 2));
  XCTAssertTrue(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 4, 3, 3), 2));
  XCTAssertTrue(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(4, 3, 3, 3), 2));
  XCTAssertTrue(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 3, 3, 4), 2));
  XCTAssertTrue(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 3, 4, 3), 2));
}

- (void)testFuzzyNotEqualRects
{
  CGRect referenceRect = CGRectMake(3, 3, 3, 3);
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(5, 5, 5, 5), 1));
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 5, 3, 3), 1));
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(5, 3, 3, 3), 1));
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 3, 3, 5), 1));
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(3, 3, 5, 3), 1));
}

- (void)testFuzzyEqualRectsSymmetry
{
  CGRect referenceRect = CGRectMake(0, 0, 2, 2);
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(1, 1, 3, 3), 1));
  XCTAssertFalse(FBRectFuzzyEqualToRect(referenceRect, CGRectMake(-1, -1, 1, 1), 1));
}

- (void)testSizeInversion
{
  const CGSize screenSizePortrait = CGSizeMake(10, 15);
  const CGSize screenSizeLandscape = CGSizeMake(15, 10);
  const CGFloat t = FBDefaultFrameFuzzyThreshold;
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizePortrait, FBAdjustDimensionsForApplication(screenSizePortrait, UIInterfaceOrientationPortrait), t));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizePortrait, FBAdjustDimensionsForApplication(screenSizePortrait, UIInterfaceOrientationPortraitUpsideDown), t));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizeLandscape, FBAdjustDimensionsForApplication(screenSizePortrait, UIInterfaceOrientationLandscapeLeft), t));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizeLandscape, FBAdjustDimensionsForApplication(screenSizePortrait, UIInterfaceOrientationLandscapeRight), t));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizeLandscape, FBAdjustDimensionsForApplication(screenSizeLandscape, UIInterfaceOrientationLandscapeLeft), t));
  XCTAssertTrue(FBSizeFuzzyEqualToSize(screenSizeLandscape, FBAdjustDimensionsForApplication(screenSizeLandscape, UIInterfaceOrientationLandscapeRight), t));
}

- (void)testScrollGestureOffsetsWithMatchingFrames
{
  CGRect frame = CGRectMake(20, 200, 300, 400);
  CGVector proportion = CGVectorMake(0.5, 0.75);
  CGVector vector = CGVectorMake(0, -200);
  CGVector startOffset, endOffset;
  XCTAssertTrue(FBScrollGestureOffsets(frame, frame, proportion, vector, &startOffset, &endOffset));
  XCTAssertTrue(FBVectorFuzzyEqualToVector(startOffset, CGVectorMake(0.5, 0.75), 0.01));
  XCTAssertTrue(FBVectorFuzzyEqualToVector(endOffset, CGVectorMake(0.5, 0.25), 0.01));
}

- (void)testScrollGestureOffsetsWithRescaledAnchorFrame
{
  // Simulates a compatibility-mode window: anchorFrame is scrollingFrame scaled by ~2.19x,
  // same origin - offsets should still land within [0, 1] instead of drifting outside it.
  CGRect scrollingFrame = CGRectMake(20, 202, 335, 420);
  CGRect anchorFrame = CGRectMake(20, 202, 733, 920);
  CGVector proportion = CGVectorMake(0.5, 0.75);
  CGVector vector = CGVectorMake(0, -250);
  CGVector startOffset, endOffset;
  XCTAssertTrue(FBScrollGestureOffsets(scrollingFrame, anchorFrame, proportion, vector, &startOffset, &endOffset));
  XCTAssertTrue(startOffset.dx >= 0 && startOffset.dx <= 1);
  XCTAssertTrue(startOffset.dy >= 0 && startOffset.dy <= 1);
  XCTAssertTrue(endOffset.dx >= 0 && endOffset.dx <= 1);
  XCTAssertTrue(endOffset.dy >= 0 && endOffset.dy <= 1);
}

- (void)testScrollGestureOffsetsWithEmptyFrame
{
  CGVector startOffset = CGVectorMake(-1, -1);
  CGVector endOffset = CGVectorMake(-1, -1);
  XCTAssertFalse(FBScrollGestureOffsets(CGRectZero, CGRectMake(0, 0, 100, 100), CGVectorMake(0.5, 0.5), CGVectorMake(0, -50), &startOffset, &endOffset));
  XCTAssertFalse(FBScrollGestureOffsets(CGRectMake(0, 0, 100, 100), CGRectZero, CGVectorMake(0.5, 0.5), CGVectorMake(0, -50), &startOffset, &endOffset));
  // Untouched on failure
  XCTAssertTrue(startOffset.dx == -1 && startOffset.dy == -1);
  XCTAssertTrue(endOffset.dx == -1 && endOffset.dy == -1);
}

@end
