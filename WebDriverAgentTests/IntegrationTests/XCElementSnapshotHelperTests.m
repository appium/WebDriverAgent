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
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
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
  NSArray<id<FBXCElementSnapshot>> *matchingSnapshots = [[FBXCElementSnapshotWrapper ensureWrapped:
                                                          [self.testedView fb_customSnapshot]]
                                                         fb_descendantsMatchingType:XCUIElementTypeButton];
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
  id<FBXCElementSnapshot> windowSnapshot = [[FBXCElementSnapshotWrapper ensureWrapped:
                                             [self.testedView fb_customSnapshot]]
                                            fb_parentMatchingType:XCUIElementTypeWindow];
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
  id<FBXCElementSnapshot> datePicker = [[FBXCElementSnapshotWrapper ensureWrapped:
                                         [todayPickerWheel fb_customSnapshot]]
                                        fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeDatePicker), @(XCUIElementTypeWindow)]];
  XCTAssertNotNil(datePicker);
  XCTAssertEqual(datePicker.elementType, XCUIElementTypeDatePicker);
}

- (void)testParentMatchingOneOfTypesWithXCUIElementTypeAny
{
  XCUIElement *todayPickerWheel = self.testedApplication.pickerWheels[@"Today"];
  FBAssertWaitTillBecomesTrue(todayPickerWheel.exists);
  id<FBXCElementSnapshot> otherSnapshot =[[FBXCElementSnapshotWrapper ensureWrapped:
                                           [todayPickerWheel fb_customSnapshot]]
                                          fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeAny)]];
  XCTAssertNotNil(otherSnapshot);
}

- (void)testParentMatchingOneOfTypesWithAbsentParents
{
  XCUIElement *todayPickerWheel = self.testedApplication.pickerWheels[@"Today"];
  FBAssertWaitTillBecomesTrue(todayPickerWheel.exists);
  id<FBXCElementSnapshot> otherSnapshot = [[FBXCElementSnapshotWrapper ensureWrapped:
                                            [todayPickerWheel fb_customSnapshot]]
                                      fb_parentMatchingOneOfTypes:@[@(XCUIElementTypeTab), @(XCUIElementTypeLink)]];
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
  id<FBXCElementSnapshot> scrollView = [[FBXCElementSnapshotWrapper ensureWrapped:
                                         [threeStaticText fb_customSnapshot]]
                                   fb_parentMatchingOneOfTypes:acceptedParents
                                                        filter:^BOOL(id<FBXCElementSnapshot> snapshot) {
    return [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] isWDVisible];
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
  id<FBXCElementSnapshot> scrollView = [[FBXCElementSnapshotWrapper ensureWrapped:
                                         [threeStaticText fb_customSnapshot]]
                                        fb_parentMatchingOneOfTypes:acceptedParents
                                                             filter:^BOOL(id<FBXCElementSnapshot> snapshot) {
    return NO;
  }];
  XCTAssertNil(scrollView);
}

- (void)testDescendantsCellSnapshots
{
  XCUIElement *scrollView = self.testedApplication.scrollViews[@"scrollView"];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
  NSArray *cells = [[FBXCElementSnapshotWrapper ensureWrapped:
                     [scrollView fb_customSnapshot]]
                    fb_descendantsCellSnapshots];
  XCTAssertGreaterThanOrEqual(cells.count, 10);
  id<FBXCElementSnapshot> element = cells.firstObject;
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
  id<FBXCElementSnapshot> xcuiElementCell = [[FBXCElementSnapshotWrapper ensureWrapped:
                                              [threeStaticText fb_customSnapshot]]
                                             fb_parentCellSnapshot];
  XCTAssertEqual(xcuiElementCell.elementType, 75);
}

@end
