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
#import "FBXPath.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement.h"
#import "XCUIElement+FBFind.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"


@interface FBXPathIntegrationTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *testedView;
@end

@implementation FBXPathIntegrationTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
  });
  self.testedView = self.testedApplication.otherElements[@"MainView"];
  XCTAssertTrue(self.testedView.exists);
  [self.testedView fb_nativeResolve];
  FBAssertWaitTillBecomesTrue(self.testedView.buttons.count > 0);
}

- (void)testSingleDescendantXMLRepresentation
{
  XCUIElement *matchingElement = self.testedView.buttons.fb_firstMatch;
  FBAssertWaitTillBecomesTrue(nil != matchingElement.fb_lastSnapshot);

  XCElementSnapshot *snapshot = matchingElement.fb_lastSnapshot;
  NSString *xmlStr = [FBXPath xmlStringWithRootElement:snapshot];
  XCTAssertNotNil(xmlStr);
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\"/>\n", snapshot.wdType, snapshot.wdType, snapshot.wdName, snapshot.wdLabel, snapshot.wdEnabled ? @"true" : @"false", snapshot.wdVisible ? @"true" : @"false", [snapshot.wdRect[@"x"] stringValue], [snapshot.wdRect[@"y"] stringValue], [snapshot.wdRect[@"width"] stringValue], [snapshot.wdRect[@"height"] stringValue]];
  XCTAssertEqualObjects(xmlStr, expectedXml);
}

- (void)testFindMatchesInElement
{
  NSArray *matchingSnapshots = [FBXPath matchesWithRootElement:self.testedApplication forQuery:@"//XCUIElementTypeButton"];
  XCTAssertEqual([matchingSnapshots count], 4);
  for (id<FBElement> element in matchingSnapshots) {
    XCTAssertTrue([element.wdType isEqualToString:@"XCUIElementTypeButton"]);
  }
}

- (void)testFindMatchesInElementWithDotNotation
{
  NSArray *matchingSnapshots = [FBXPath matchesWithRootElement:self.testedApplication forQuery:@".//XCUIElementTypeButton"];
  XCTAssertEqual([matchingSnapshots count], 4);
  for (id<FBElement> element in matchingSnapshots) {
    XCTAssertTrue([element.wdType isEqualToString:@"XCUIElementTypeButton"]);
  }
}

@end
