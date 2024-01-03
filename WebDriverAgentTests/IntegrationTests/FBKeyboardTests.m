/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBMacros.h"
#import "FBIntegrationTestCase.h"
#import "FBKeyboard.h"
#import "FBRunLoopSpinner.h"
#import "XCUIApplication+FBHelpers.h"

@interface FBKeyboardTests : FBIntegrationTestCase
@end

@implementation FBKeyboardTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  [self goToAttributesPage];
}

- (void)testKeyboardDismissal
{
  XCUIElement *textField = self.testedApplication.textFields[@"aIdentifier"];
  [textField tap];

  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
    // A workaround until find out to clear tutorial on iOS 15
    XCUIElement *textField = self.testedApplication.staticTexts[@"Continue"];
    if (textField.hittable) {
      [textField tap];
    }
  }

  NSError *error;
  XCTAssertTrue([FBKeyboard waitUntilVisibleForApplication:self.testedApplication timeout:1 error:&error]);
  XCTAssertNil(error);
  if ([UIDevice.currentDevice userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    XCTAssertTrue([self.testedApplication fb_dismissKeyboardWithKeyNames:nil error:&error]);
    XCTAssertNil(error);
  } else {
    XCTAssertFalse([self.testedApplication fb_dismissKeyboardWithKeyNames:@[@"return"] error:&error]);
    XCTAssertNotNil(error);
  }
}

- (void)testKeyboardPresenceVerification
{
  NSError *error;
  XCTAssertFalse([FBKeyboard waitUntilVisibleForApplication:self.testedApplication timeout:1 error:&error]);
  XCTAssertNotNil(error);
}

@end
