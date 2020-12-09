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
#import "FBFindElementCommands.h"
#import "FBTestMacros.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBAccessibility.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBXCodeCompatibility.h"

@interface FBElementAttributeTests : FBIntegrationTestCase
@end

@implementation FBElementAttributeTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAttributesPage];
  });
}

- (void)testElementAccessibilityAttributes
{
  // "Button" is accessibility element, and therefore isn't accessibility container
  XCUIElement *buttonElement = self.testedApplication.buttons[@"Button"];
  XCTAssertTrue(buttonElement.exists);
  XCTAssertTrue(buttonElement.fb_isAccessibilityElement);
  XCTAssertFalse(buttonElement.isWDAccessibilityContainer);
}

- (void)testContainerAccessibilityAttributes
{
  // "not_accessible" isn't accessibility element, but contains accessibility elements, so it is accessibility container
  XCUIElement *inaccessibleButtonElement = self.testedApplication.buttons[@"not_accessible"];
  XCTAssertTrue(inaccessibleButtonElement.exists);
  XCTAssertFalse(inaccessibleButtonElement.fb_isAccessibilityElement);
  if (@available(iOS 13.0, *)) {
    // FIXME: Xcode 11 environment returns false even if iOS 12
    // We must fix here to XCTAssertTrue if Xcode version will return the value properly
    XCTAssertFalse(inaccessibleButtonElement.isWDAccessibilityContainer);
  } else {
    // Xcode 10 and the below works fine
    XCTAssertTrue(inaccessibleButtonElement.isWDAccessibilityContainer);
  }
}

- (void)testIgnoredAccessibilityAttributes
{
  // Images are neither accessibility elements nor contain them, so both checks should fail
  XCUIElement *imageElement = self.testedApplication.images.fb_firstMatch;
  XCTAssertTrue(imageElement.exists);
  XCTAssertFalse(imageElement.fb_isAccessibilityElement);
  XCTAssertFalse(imageElement.isWDAccessibilityContainer);
}

- (void)testButtonAttributes
{
  XCUIElement *element = self.testedApplication.buttons[@"Button"];
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeButton");
  XCTAssertEqualObjects(element.wdName, @"Button");
  XCTAssertEqualObjects(element.wdLabel, @"Button");
  XCTAssertNil(element.wdValue);
  XCTAssertFalse(element.wdSelected);
  [element tap];
  XCTAssertTrue(element.wdValue.boolValue);
  XCTAssertTrue(element.wdSelected);
}

- (void)testLabelAttributes
{
  XCUIElement *element = self.testedApplication.staticTexts[@"Label"];
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeStaticText");
  XCTAssertEqualObjects(element.wdName, @"Label");
  XCTAssertEqualObjects(element.wdLabel, @"Label");
  XCTAssertEqualObjects(element.wdValue, @"Label");
}

- (void)testIndexAttributes
{
  XCUIElement *element = self.testedApplication.buttons[@"Button"];
  XCTAssertTrue(element.exists);
  XCTAssertEqual(element.wdIndex, 2);
  XCUIElement *element2 = self.testedApplication;
  XCTAssertTrue(element2.exists);
  XCTAssertEqual(element2.wdIndex, 0);
}

- (void)testTextFieldAttributes
{
  XCUIElement *element = self.testedApplication.textFields[@"Value"];
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeTextField");
  XCTAssertNil(element.wdName);
  XCTAssertEqualObjects(element.wdLabel, @"");
  XCTAssertEqualObjects(element.wdValue, @"Value");
}

- (void)testTextFieldWithAccessibilityIdentifiersAttributes
{
  XCUIElement *element = self.testedApplication.textFields[@"aIdentifier"];
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeTextField");
  XCTAssertEqualObjects(element.wdName, @"aIdentifier");
  XCTAssertEqualObjects(element.wdLabel, @"aLabel");
  XCTAssertEqualObjects(element.wdValue, @"Value2");
}

- (void)testSegmentedControlAttributes
{
  XCUIElement *element = self.testedApplication.segmentedControls.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeSegmentedControl");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertNil(element.wdValue);
}

- (void)testSliderAttributes
{
  XCUIElement *element = self.testedApplication.sliders.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeSlider");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertEqualObjects(element.wdValue, @"50%");
}

- (void)testActivityIndicatorAttributes
{
  XCUIElement *element = self.testedApplication.activityIndicators.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeActivityIndicator");
  XCTAssertEqualObjects(element.wdName, @"Progress halted");
  XCTAssertEqualObjects(element.wdLabel, @"Progress halted");
  XCTAssertEqualObjects(element.wdValue, @"0");
}

- (void)testSwitchAttributes
{
  XCUIElement *element = self.testedApplication.switches.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeSwitch");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertEqualObjects(element.wdValue, @"1");
  XCTAssertFalse(element.wdSelected);
  XCTAssertTrue([element fb_tapWithError:nil]);
  XCTAssertEqualObjects(element.wdValue, @"0");
  XCTAssertFalse(element.wdSelected);
}

- (void)testPickerWheelAttributes
{
  XCUIElement *element = self.testedApplication.pickerWheels[@"Today"];
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypePickerWheel");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertEqualObjects(element.wdValue, @"Today");
}

- (void)testPageIndicatorAttributes
{
  XCUIElement *element = self.testedApplication.pageIndicators.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypePageIndicator");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertEqualObjects(element.wdValue, @"page 1 of 3");
}

- (void)testTextViewAttributes
{
  XCUIElement *element = self.testedApplication.textViews.element;
  XCTAssertTrue(element.exists);
  XCTAssertEqualObjects(element.wdType, @"XCUIElementTypeTextView");
  XCTAssertNil(element.wdName);
  XCTAssertNil(element.wdLabel);
  XCTAssertEqualObjects(element.wdValue, @"Text Field long text");
}

@end
