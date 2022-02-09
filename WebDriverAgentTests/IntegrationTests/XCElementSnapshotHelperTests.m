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
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBXCodeCompatibility.h"

@interface XCElementSnapshotHelperTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *testedView;
@end

@implementation XCElementSnapshotHelperTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
  });
  self.testedView = self.testedApplication.otherElements[@"MainView"];
  XCTAssertTrue(self.testedView.exists);
}

- (void)testDescendantsMatchingType
{
  NSSet<NSString *> *expectedLabels = [NSSet setWithArray:@[
    @"Alerts",
    @"Attributes",
    @"Scrolling",
    @"Deadlock app",
    @"Touch",
  ]];
  NSArray<XCElementSnapshot *> *matchingSnapshots = [self.testedView.fb_takeSnapshot fb_descendantsMatchingType:XCUIElementTypeButton];
  XCTAssertEqual(matchingSnapshots.count, expectedLabels.count);
  NSArray<NSString *> *labels = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.label"];
  XCTAssertEqualObjects([NSSet setWithArray:labels], expectedLabels);

  NSArray<NSNumber *> *types = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.elementType"];
  XCTAssertEqual(types.count, 1, @"matchingSnapshots should contain only one type");
  XCTAssertEqualObjects(types.lastObject, @(XCUIElementTypeButton), @"matchingSnapshots should contain only one type");
}

- (void)testParentMatchingType
{
  XCUIElement *button = self.testedApplication.buttons[@"Alerts"];
  FBAssertWaitTillBecomesTrue(button.exists);
  XCElementSnapshot *windowSnapshot = [button.fb_takeSnapshot fb_parentMatchingType:XCUIElementTypeWindow];
  XCTAssertNotNil(windowSnapshot);
  XCTAssertEqual(windowSnapshot.elementType, XCUIElementTypeWindow);
}

@end

@interface XCElementSnapshotHelperTests_AttributePage : FBIntegrationTestCase
@end

@implementation XCElementSnapshotHelperTests_AttributePage

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAttributesPage];
  });
}

- (void)testParentMatchingOneOfTypes
{
  XCUIElement *todayPickerWheel = self.testedApplication.pickerWheels[@"Today"];
  FBAssertWaitTillBecomesTrue(todayPickerWheel.exists);
  XCElementSnapshot *datePicker = [todayPickerWheel.fb_takeSnapshot fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeDatePicker), @(XCUIElementTypeWindow)]];
  XCTAssertNotNil(datePicker);
  XCTAssertEqual(datePicker.elementType, XCUIElementTypeDatePicker);
}

- (void)testParentMatchingOneOfTypesWithXCUIElementTypeAny
{
  XCUIElement *todayPickerWheel = self.testedApplication.pickerWheels[@"Today"];
  FBAssertWaitTillBecomesTrue(todayPickerWheel.exists);
  XCElementSnapshot *otherSnapshot;
  if (@available(iOS 13.0, *)) {
    // </XCUIElementTypeOther>
    //   <XCUIElementTypeDatePicker>
    //     <XCUIElementTypePicker>
    //       <XCUIElementTypePickerWheel value="Today"...>
    otherSnapshot = [[[todayPickerWheel.fb_takeSnapshot fb_parentMatchingType:XCUIElementTypePicker]
                      fb_parentMatchingType:XCUIElementTypeDatePicker] fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeAny), @(XCUIElementTypeWindow)]];
  } else {
    otherSnapshot = [todayPickerWheel.fb_takeSnapshot fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeAny),
                                                                                    @(XCUIElementTypeWindow)]];
  }
  XCTAssertNotNil(otherSnapshot);
  XCTAssertEqual(otherSnapshot.elementType, XCUIElementTypeOther);
}

- (void)testParentMatchingOneOfTypesWithAbsentParents
{
  XCUIElement *todayPickerWheel = self.testedApplication.pickerWheels[@"Today"];
  FBAssertWaitTillBecomesTrue(todayPickerWheel.exists);
  XCElementSnapshot *otherSnapshot = [todayPickerWheel.fb_takeSnapshot fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeTab), @(XCUIElementTypeLink)]];
  XCTAssertNil(otherSnapshot);
}

@end

@interface XCElementSnapshotHelperTests_ScrollView : FBIntegrationTestCase
@end

@implementation XCElementSnapshotHelperTests_ScrollView

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToScrollPageWithCells:false];
  });
}

- (void)testParentMatchingOneOfTypesWithFilter
{
  XCUIElement *threeStaticText = self.testedApplication.staticTexts[@"3"];
  FBAssertWaitTillBecomesTrue(threeStaticText.exists);
  NSArray *acceptedParents = @[
                               @(XCUIElementTypeScrollView),
                               @(XCUIElementTypeCollectionView),
                               @(XCUIElementTypeTable),
                               ];
  XCElementSnapshot *scrollView = [threeStaticText.fb_takeSnapshot fb_parentMatchingOneOfTypes:acceptedParents
                                                                                        filter:^(XCElementSnapshot *snapshot) {
                                                                                          return [snapshot isWDVisible];
                                                                                        }];
  XCTAssertEqualObjects(scrollView.identifier, @"scrollView");
}

- (void)testParentMatchingOneOfTypesWithFilterRetruningNo
{
  XCUIElement *threeStaticText = self.testedApplication.staticTexts[@"3"];
  FBAssertWaitTillBecomesTrue(threeStaticText.exists);
  NSArray *acceptedParents = @[
                               @(XCUIElementTypeScrollView),
                               @(XCUIElementTypeCollectionView),
                               @(XCUIElementTypeTable),
                               ];
  XCElementSnapshot *scrollView = [threeStaticText.fb_takeSnapshot fb_parentMatchingOneOfTypes:acceptedParents
                                                                                        filter:^(XCElementSnapshot *snapshot) {
                                                                                          return NO;
                                                                                        }];
  XCTAssertNil(scrollView);
}

- (void)testDescendantsCellSnapshots
{
  XCUIElement *scrollView = self.testedApplication.scrollViews[@"scrollView"];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
  NSArray *cells = [scrollView.fb_takeSnapshot fb_descendantsCellSnapshots];
  XCTAssertGreaterThanOrEqual(cells.count, 10);
  XCElementSnapshot *element = cells.firstObject;
  XCTAssertEqualObjects(element.label, @"0");
}

@end

@interface XCElementSnapshotHelperTests_ScrollViewCells : FBIntegrationTestCase
@end

@implementation XCElementSnapshotHelperTests_ScrollViewCells

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToScrollPageWithCells:true];
  });
}

- (void)testParentCellSnapshot
{
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
  XCUIElement *threeStaticText = self.testedApplication.staticTexts[@"3"];
  XCElementSnapshot *xcuiElementCell = [threeStaticText.fb_takeSnapshot fb_parentCellSnapshot];
  XCTAssertEqual(xcuiElementCell.elementType, 75);
}

@end
