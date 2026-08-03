/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/FBXCElementSnapshot.h>

#import "XCUIElementDouble.h"
#import "FBXCElementSnapshotDouble.h"
#import "FBTVNavigationTracker.h"
#import "FBTVNavigationTracker-Private.h"

@interface FBTVNavigationTrackerTests : XCTestCase
@end

@implementation FBTVNavigationTrackerTests

- (void)testHorizontalDirectionWithItemShouldBeRight
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker horizontalDirectionWithItem:item andDelta:0.1];
  XCTAssertEqual(FBTVDirectionRight, direction);
}

- (void)testHorizontalDirectionWithItemShouldBeLeft
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker horizontalDirectionWithItem:item andDelta:-0.1];
  XCTAssertEqual(FBTVDirectionLeft, direction);
}

- (void)testHorizontalDirectionWithItemShouldBeNone
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker horizontalDirectionWithItem:item andDelta:DBL_EPSILON];
  XCTAssertEqual(FBTVDirectionNone, direction);
}

- (void)testVerticalDirectionWithItemShouldBeDown
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker verticalDirectionWithItem:item andDelta:0.1];
  XCTAssertEqual(FBTVDirectionDown, direction);
}

- (void)testVerticalDirectionWithItemShouldBeUp
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker verticalDirectionWithItem:item andDelta:-0.1];
  XCTAssertEqual(FBTVDirectionUp, direction);
}

- (void)testVerticalDirectionWithItemShouldBeNone
{
  XCUIElementDouble *el1 = XCUIElementDouble.new;

  FBTVNavigationItem *item = [FBTVNavigationItem itemWithUid:@"123456789"];
  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)el1];

  FBTVDirection direction = [tracker verticalDirectionWithItem:item andDelta:DBL_EPSILON];
  XCTAssertEqual(FBTVDirectionNone, direction);
}

#pragma mark - directionTowardsTargetFromFocusedElementSnapshot:

- (FBTVNavigationTracker *)trackerWithTargetFrame:(CGRect)targetFrame
{
  XCUIElementDouble *targetElement = XCUIElementDouble.new;
  targetElement.wdFrame = targetFrame;
  return [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];
}

- (void)testDirectionTowardsTargetFromFocusedElementSnapshotShouldPointRight
{
  // Target sits to the right of the currently focused element.
  FBTVNavigationTracker *tracker = [self trackerWithTargetFrame:CGRectMake(100, 0, 0, 0)];
  FBXCElementSnapshotDouble *focusedSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:CGRectMake(0, 0, 0, 0) hasFocus:YES];

  FBTVDirection direction = [tracker directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot];

  XCTAssertEqual(FBTVDirectionRight, direction);
}

- (void)testDirectionTowardsTargetFromFocusedElementSnapshotShouldPointUp
{
  // Target sits above the currently focused element.
  FBTVNavigationTracker *tracker = [self trackerWithTargetFrame:CGRectMake(0, -100, 0, 0)];
  FBXCElementSnapshotDouble *focusedSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:CGRectMake(0, 0, 0, 0) hasFocus:YES];

  FBTVDirection direction = [tracker directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot];

  XCTAssertEqual(FBTVDirectionUp, direction);
}

- (void)testDirectionTowardsTargetFromFocusedElementSnapshotShouldNotSuggestTheSameDirectionTwiceInARow
{
  // Same (unmoved) focused snapshot polled twice: the horizontal move gets
  // suggested once, then withheld on the next call, per the "don't repeat a
  // direction" bookkeeping in -directionWithItem:delta:positiveDirection:negativeDirection:.
  FBTVNavigationTracker *tracker = [self trackerWithTargetFrame:CGRectMake(100, 0, 0, 0)];
  FBXCElementSnapshotDouble *focusedSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:CGRectMake(0, 0, 0, 0) hasFocus:YES];

  FBTVDirection firstDirection = [tracker directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot];
  XCTAssertEqual(FBTVDirectionRight, firstDirection);

  FBTVDirection secondDirection = [tracker directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot];
  XCTAssertEqual(FBTVDirectionNone, secondDirection);
}

@end
