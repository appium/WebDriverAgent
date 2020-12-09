/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "XCUIElementDouble.h"
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

@end
