/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"

#import "FBMacros.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBScrolling.h"
#import "XCUIElement+FBClassChain.h"
#import "FBXCodeCompatibility.h"


@interface FBScrollingTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *scrollView;
@end

@implementation FBScrollingTests

+ (BOOL)shouldShowCells
{
  return YES;
}

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  [self goToScrollPageWithCells:YES];
  self.scrollView = [[self.testedApplication.query descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"scrollView"].element;
}

- (void)testCellVisibility
{
  FBAssertVisibleCell(@"0");
  FBAssertVisibleCell(@"10");
  XCUIElement *cell10 = FBCellElementWithLabel(@"10");
  XCTAssertEqual([cell10 isWDHittable], [cell10 isHittable]);
  FBAssertInvisibleCell(@"30");
  FBAssertInvisibleCell(@"50");
  XCUIElement *cell50 = FBCellElementWithLabel(@"50");
  XCTAssertEqual([cell50 isWDHittable], [cell50 isHittable]);
}

- (void)testSimpleScroll
{
  if (SYSTEM_VERSION_LESS_THAN(@"16.0")) {
    // This test is unstable in CI env
    return;
  }

  FBAssertVisibleCell(@"0");
  FBAssertVisibleCell(@"10");
  [self.scrollView fb_scrollDownByNormalizedDistance:1.0];
  FBAssertInvisibleCell(@"0");
  FBAssertInvisibleCell(@"10");
  XCTAssertTrue(self.testedApplication.staticTexts.count > 0);
  [self.scrollView fb_scrollUpByNormalizedDistance:1.0];
  FBAssertVisibleCell(@"0");
  FBAssertVisibleCell(@"10");
}

- (void)testScrollToVisible
{
  NSString *cellName = @"30";
  FBAssertInvisibleCell(cellName);
  NSError *error;
  XCTAssertTrue([FBCellElementWithLabel(cellName) fb_scrollToVisibleWithError:&error]);
  XCTAssertNil(error);
  FBAssertVisibleCell(cellName);
}

- (void)testFarScrollToVisible
{
  NSString *cellName = @"80";
  NSError *error;
  FBAssertInvisibleCell(cellName);
  XCTAssertTrue([FBCellElementWithLabel(cellName) fb_scrollToVisibleWithError:&error]);
  XCTAssertNil(error);
  FBAssertVisibleCell(cellName);
}

- (void)testNativeFarScrollToVisible
{
  if (SYSTEM_VERSION_LESS_THAN(@"16.0")) {
    // This test is unstable in CI env
    return;
  }

  NSString *cellName = @"80";
  NSError *error;
  FBAssertInvisibleCell(cellName);
  XCTAssertTrue([FBCellElementWithLabel(cellName) fb_nativeScrollToVisibleWithError:&error]);
  XCTAssertNil(error);
  FBAssertVisibleCell(cellName);
}

- (void)testAttributeWithNullScrollToVisible
{
  NSError *error;
  NSArray<XCUIElement *> *queryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"**/XCUIElementTypeTable/XCUIElementTypeCell[60]" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(queryMatches.count, 1);
  XCUIElement *element = queryMatches.firstObject;
  XCTAssertFalse(element.fb_isVisible);
  [element fb_scrollToVisibleWithError:&error];
  XCTAssertNil(error);
  XCTAssertTrue(element.fb_isVisible);
  
  if (SYSTEM_VERSION_LESS_THAN(@"16.0")) {
    // This test is unstable in CI env
    return;
  }

  [element tap];
  XCTAssertTrue(element.wdSelected);
}

@end

