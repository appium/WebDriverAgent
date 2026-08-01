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

#pragma mark - pollFocusStateWithApplicationSnapshot:direction:

- (XCUIElementDouble *)targetElementWithElementId:(unsigned long long)elementId frame:(CGRect)frame
{
  XCUIElementDouble *targetElement = XCUIElementDouble.new;
  targetElement.wdFrame = frame;
  targetElement.wdUID = [FBXCElementSnapshotDouble wdUIDForElementId:elementId];
  return targetElement;
}

- (void)testPollFocusStateShouldReturnFocusedWhenTargetAlreadyHasFocus
{
  CGRect frame = CGRectMake(0, 0, 10, 10);
  XCUIElementDouble *targetElement = [self targetElementWithElementId:1 frame:frame];
  FBXCElementSnapshotDouble *targetSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:frame hasFocus:YES];
  FBXCElementSnapshotDouble *root = [FBXCElementSnapshotDouble snapshotWithElementId:0 frame:CGRectZero hasFocus:NO];
  root.children = @[targetSnapshot];

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];
  FBTVDirection direction = FBTVDirectionUp;
  FBTVFocusState state = [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root
                                                                direction:&direction];

  XCTAssertEqual(FBTVFocusStateFocused, state);
  XCTAssertEqual(FBTVDirectionNone, direction);
}

- (void)testPollFocusStateShouldReturnGoneWhenTargetIsNotInTheTree
{
  XCUIElementDouble *targetElement = [self targetElementWithElementId:1 frame:CGRectMake(0, 0, 10, 10)];
  FBXCElementSnapshotDouble *otherSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:2 frame:CGRectMake(50, 50, 10, 10) hasFocus:YES];
  FBXCElementSnapshotDouble *root = [FBXCElementSnapshotDouble snapshotWithElementId:0 frame:CGRectZero hasFocus:NO];
  root.children = @[otherSnapshot];

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];
  FBTVDirection direction = FBTVDirectionUp;
  FBTVFocusState state = [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root
                                                                direction:&direction];

  XCTAssertEqual(FBTVFocusStateGone, state);
}

- (void)testPollFocusStateShouldReturnPendingWithNoDirectionWhenNothingIsFocusedYet
{
  CGRect frame = CGRectMake(0, 0, 10, 10);
  XCUIElementDouble *targetElement = [self targetElementWithElementId:1 frame:frame];
  FBXCElementSnapshotDouble *targetSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:frame hasFocus:NO];
  FBXCElementSnapshotDouble *root = [FBXCElementSnapshotDouble snapshotWithElementId:0 frame:CGRectZero hasFocus:NO];
  root.children = @[targetSnapshot];

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];
  FBTVDirection direction = FBTVDirectionUp;
  FBTVFocusState state = [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root
                                                                direction:&direction];

  XCTAssertEqual(FBTVFocusStatePending, state);
  XCTAssertEqual(FBTVDirectionNone, direction);
}

- (void)testPollFocusStateShouldReturnDirectionTowardsTarget
{
  // Target sits to the right of the currently focused element.
  XCUIElementDouble *targetElement = [self targetElementWithElementId:1 frame:CGRectMake(100, 0, 0, 0)];
  FBXCElementSnapshotDouble *targetSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:CGRectMake(100, 0, 0, 0) hasFocus:NO];
  FBXCElementSnapshotDouble *focusedSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:2 frame:CGRectMake(0, 0, 0, 0) hasFocus:YES];
  FBXCElementSnapshotDouble *root = [FBXCElementSnapshotDouble snapshotWithElementId:0 frame:CGRectZero hasFocus:NO];
  root.children = @[targetSnapshot, focusedSnapshot];

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];
  FBTVDirection direction = FBTVDirectionNone;
  FBTVFocusState state = [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root
                                                                direction:&direction];

  XCTAssertEqual(FBTVFocusStatePending, state);
  XCTAssertEqual(FBTVDirectionRight, direction);
}

- (void)testPollFocusStateShouldNotSuggestTheSameDirectionTwiceInARow
{
  // Same fixture as testPollFocusStateShouldReturnDirectionTowardsTarget: the
  // horizontal move gets suggested once, then withheld on the next poll of
  // the same (unmoved) focus, per the "don't repeat a direction" bookkeeping
  // in -directionWithItem:delta:positiveDirection:negativeDirection:.
  XCUIElementDouble *targetElement = [self targetElementWithElementId:1 frame:CGRectMake(100, 0, 0, 0)];
  FBXCElementSnapshotDouble *targetSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:1 frame:CGRectMake(100, 0, 0, 0) hasFocus:NO];
  FBXCElementSnapshotDouble *focusedSnapshot = [FBXCElementSnapshotDouble snapshotWithElementId:2 frame:CGRectMake(0, 0, 0, 0) hasFocus:YES];
  FBXCElementSnapshotDouble *root = [FBXCElementSnapshotDouble snapshotWithElementId:0 frame:CGRectZero hasFocus:NO];
  root.children = @[targetSnapshot, focusedSnapshot];

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:(XCUIElement *)targetElement];

  FBTVDirection firstDirection = FBTVDirectionNone;
  [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root direction:&firstDirection];
  XCTAssertEqual(FBTVDirectionRight, firstDirection);

  FBTVDirection secondDirection = FBTVDirectionNone;
  [tracker pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)root direction:&secondDirection];
  XCTAssertEqual(FBTVDirectionNone, secondDirection);
}

@end
