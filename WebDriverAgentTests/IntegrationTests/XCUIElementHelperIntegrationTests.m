/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import "XCTest/XCUIElementTypes.h"

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "FBElement.h"
#import "FBElementUtils.h"
#import "FBXCElementSnapshot.h"
#import "XCUIElement+FBUtilities.h"

@interface XCUIElementHelperIntegrationTests : FBIntegrationTestCase
@end

@implementation XCUIElementHelperIntegrationTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  [self goToAlertsPage];
}

- (void)testDescendantsFiltering
{
  NSArray<XCUIElement *> *buttons = self.testedApplication.buttons.allElementsBoundByIndex;
  XCTAssertTrue(buttons.count > 0);
  NSArray<XCUIElement *> *windows = self.testedApplication.windows.allElementsBoundByIndex;
  XCTAssertTrue(windows.count > 0);
  
  NSMutableArray<XCUIElement *> *allElements = [NSMutableArray array];
  [allElements addObjectsFromArray:buttons];
  [allElements addObjectsFromArray:windows];
  
  NSMutableArray<id<FBXCElementSnapshot>> *buttonSnapshots = [NSMutableArray array];
  [buttonSnapshots addObject:[buttons.firstObject fb_customSnapshot]];

  NSArray<XCUIElement *> *result = [self.testedApplication fb_filterDescendantsWithSnapshots:buttonSnapshots
                                                                                onlyChildren:NO];
  XCTAssertEqual(1, result.count);
  XCTAssertEqual([result.firstObject elementType], XCUIElementTypeButton);
}

@end
