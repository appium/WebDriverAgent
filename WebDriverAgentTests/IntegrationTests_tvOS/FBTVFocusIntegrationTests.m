/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#if TARGET_OS_TV

// `XCUIElement+FBTVFocuse` is a project-internal category (not exposed as a
// Public framework header), so its two entry points are forward-declared
// here rather than imported. The real implementation - the one this suite
// exercises end to end against a live tvOS Simulator - is still the one
// linked in from WebDriverAgentLib_tvOS.framework.
@interface XCUIElement (FBTVFocuseForTesting)
- (BOOL)fb_setFocusWithError:(NSError **)error;
- (BOOL)fb_selectWithError:(NSError **)error;
@end

@interface FBTVFocusIntegrationTests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation FBTVFocusIntegrationTests

- (void)setUp
{
  [super setUp];
  self.continueAfterFailure = NO;
  self.app = [XCUIApplication new];
  [self.app launch];
  XCTAssertTrue([self.app.buttons[@"cell_0_0"] waitForExistenceWithTimeout:15]);
}

- (void)testSetFocusMovesFocusToADistantElement
{
  XCUIElement *target = self.app.buttons[@"cell_2_2"];
  XCTAssertTrue(target.exists);
  XCTAssertFalse(target.hasFocus);

  NSError *error;
  BOOL result = [target fb_setFocusWithError:&error];

  XCTAssertTrue(result);
  XCTAssertNil(error);
  XCTAssertTrue(target.hasFocus);
}

- (void)testSelectMovesFocusAndTriggersTheElementsAction
{
  XCUIElement *target = self.app.buttons[@"cell_1_2"];
  XCUIElement *statusLabel = self.app.staticTexts[@"lastSelectedLabel"];

  NSError *error;
  BOOL result = [target fb_selectWithError:&error];

  XCTAssertTrue(result);
  XCTAssertNil(error);
  XCTAssertTrue(target.hasFocus);

  NSPredicate *labelUpdated = [NSPredicate predicateWithFormat:@"label == %@", @"cell_1_2"];
  XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:labelUpdated object:statusLabel];
  [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testSetFocusOnADisabledElementFails
{
  XCUIElement *disabled = self.app.buttons[@"disabledButton"];
  XCTAssertTrue(disabled.exists);

  NSError *error;
  BOOL result = [disabled fb_setFocusWithError:&error];

  XCTAssertFalse(result);
  XCTAssertNotNil(error);
  XCTAssertFalse(disabled.hasFocus);
}

@end

#endif
