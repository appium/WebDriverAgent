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
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBSwiping.h"

@interface FBElementSwipingTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *scrollView;
@end

@implementation FBElementSwipingTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToScrollPageWithCells:YES];
    self.scrollView = [[self.testedApplication.query descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"scrollView"].element;
  });
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
  [self.scrollView fb_swipeWithDirection:@"up" velocity:@2500];
  FBAssertInvisibleCell(@"0");
  [self.scrollView fb_swipeWithDirection:@"down" velocity:@2500];
  FBAssertVisibleCell(@"0");
}

@end
