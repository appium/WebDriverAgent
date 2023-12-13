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
  [self.scrollView fb_swipeWithDirection:@"down" velocity:@2500];
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
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self openScrollView];
  });
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
