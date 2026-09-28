/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBSwiping.h"
#import "FBExceptions.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCSynthesizedEventRecord.h"
#import "XCUICoordinate.h"

@interface FBElementSwipingTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *scrollView;
- (void)openScrollView;
@end

@implementation FBElementSwipingTests

- (void)openScrollView
{
  [self launchApplication];
  [self goToScrollPageWithCells:YES];
  self.scrollView = [[self.testedApplication.query descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"scrollView"].element;
}

- (void)setUp
{
  [super setUp];
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
    [self openScrollView];
  } else {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [self openScrollView];
    });
  }
}

- (void)tearDown
{
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
    // Move to top page once to reset the scroll place
    // since iOS 15 seems cannot handle cell visibility well when the view keps the view
    [self.testedApplication terminate];
  }
}

- (void)testSwipeUp
{
  [self.scrollView fb_swipeWithDirection:@"up" velocity:nil];
  FBAssertInvisibleCell(@"0");
}

- (void)testSwipeDown
{
  [self.scrollView fb_swipeWithDirection:@"up" velocity:nil];
  FBAssertInvisibleCell(@"0");
  [self.scrollView fb_swipeWithDirection:@"down" velocity:nil];
  FBAssertVisibleCell(@"0");
}

- (void)testSwipeDownWithVelocity
{
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Failed on Azure Pipeline. Local run succeeded.");
  }
  [self.scrollView fb_swipeWithDirection:@"up" velocity:@2500];
  FBAssertInvisibleCell(@"0");
  [self.scrollView fb_swipeWithDirection:@"down" velocity:@3000];
  FBAssertVisibleCell(@"0");
}

@end

@interface FBElementSwipingApplicationTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *scrollView;
- (void)openScrollView;
@end

@implementation FBElementSwipingApplicationTests

- (void)openScrollView
{
  [self launchApplication];
  [self goToScrollPageWithCells:YES];
}

- (void)setUp
{
  [super setUp];
  // Each test (and retry) must start at row zero, not at the previous test's
  // scroll offset. A velocity-based swipe need not undo an earlier swipe.
  [self resetOrientation];
  [self openScrollView];
}

- (void)testSwipeUp
{
  [self.testedApplication fb_swipeWithDirection:@"up" velocity:nil];
  FBAssertInvisibleCell(@"0");
}

- (void)testSwipeDown
{
  [self.testedApplication fb_swipeWithDirection:@"up" velocity:nil];
  FBAssertInvisibleCell(@"0");
  [self.testedApplication fb_swipeWithDirection:@"down" velocity:nil];
  FBAssertVisibleCell(@"0");
}

- (void)testSwipeDownWithVelocity
{
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Failed on Azure Pipeline. Local run succeeded.");
  }
  [self.testedApplication fb_swipeWithDirection:@"up" velocity:@2500];
  FBAssertInvisibleCell(@"0");
  [self.testedApplication fb_swipeWithDirection:@"down" velocity:@2500];
  FBAssertVisibleCell(@"0");
}

@end

/**
 Stands in for a coordinate whose application did not deliver a usable snapshot (as happens for a
 busy application right after an app switch), which XCTest resolves to an infinite screen point.
 */
@interface FBUnresolvableCoordinate : XCUICoordinate
@end

@implementation FBUnresolvableCoordinate

- (CGPoint)screenPoint
{
  return CGPointMake(INFINITY, INFINITY);
}

@end

@interface FBPressAndDragTests : FBIntegrationTestCase
@end

@implementation FBPressAndDragTests

- (void)setUp
{
  [super setUp];
  [self resetOrientation];
  [self launchApplication];
  [self goToScrollPageWithCells:YES];
}

- (void)testPressAndDragBetweenApplicationCoordinates
{
  XCUICoordinate *start = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.7)];
  XCUICoordinate *end = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_pressAtCoordinate:start
                                                 forDuration:0.3
                                        thenDragToCoordinate:end
                                                withVelocity:XCUIGestureVelocityDefault
                                         thenHoldForDuration:0
                                                       error:&error]);
  XCTAssertNil(error);
  FBAssertInvisibleCell(@"0");
}

// https://github.com/appium/WebDriverAgent/issues/1056
- (void)testPressAndDragFailsCleanlyForUnresolvableCoordinates
{
  XCUICoordinate *start = [[FBUnresolvableCoordinate alloc] initWithElement:self.testedApplication
                                                           normalizedOffset:CGVectorMake(0.5, 0.7)];
  XCUICoordinate *end = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)];
  NSError *error;
  XCTAssertFalse([self.testedApplication fb_pressAtCoordinate:start
                                                  forDuration:0.3
                                         thenDragToCoordinate:end
                                                 withVelocity:XCUIGestureVelocityDefault
                                          thenHoldForDuration:0
                                                        error:&error]);
  XCTAssertTrue([error.localizedDescription containsString:@"Cannot resolve the on-screen position"]);
  FBAssertVisibleCell(@"0");
}

- (void)testPressDragEventKeepsDisplayIDAndTiming
{
  XCSynthesizedEventRecord *event = [XCUIApplication fb_pressDragEventFromPoint:CGPointMake(100, 500)
                                                                    forDuration:0.3
                                                                        toPoint:CGPointMake(100, 100)
                                                                pointsPerSecond:500
                                                            thenHoldForDuration:0.1
                                                                      displayID:42
                                                           interfaceOrientation:UIInterfaceOrientationPortrait];
  XCTAssertEqual(event.displayID, 42ULL);
  XCTAssertEqual(event.eventPaths.count, 1U);
  // 0.3 s press + 400 pt / 500 pt per s drag + 0.1 s hold
  XCTAssertEqualWithAccuracy(event.maximumOffset, 1.2, 0.0001);
}

- (void)testPressAndDragRejectsInvalidVelocity
{
  XCUICoordinate *start = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.7)];
  XCUICoordinate *end = [self.testedApplication coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)];
  XCTAssertThrowsSpecificNamed([self.testedApplication fb_pressAtCoordinate:start
                                                                forDuration:0
                                                       thenDragToCoordinate:end
                                                               withVelocity:0
                                                        thenHoldForDuration:0
                                                                      error:nil],
                               NSException, FBInvalidArgumentException);
}

@end
