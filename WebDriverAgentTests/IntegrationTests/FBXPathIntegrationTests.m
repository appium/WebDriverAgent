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
#import "FBMacros.h"
#import "FBTestMacros.h"
#import "FBXPath.h"
#import "FBXCodeCompatibility.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXMLGenerationOptions.h"
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
  FBAssertWaitTillBecomesTrue(self.testedView.buttons.count > 0);
}

- (id<FBXCElementSnapshot>)destinationSnapshot
{
  XCUIElement *matchingElement = self.testedView.buttons.allElementsBoundByIndex.firstObject;
  FBAssertWaitTillBecomesTrue(nil != matchingElement.fb_takeSnapshot);

  id<FBXCElementSnapshot> snapshot = matchingElement.fb_takeSnapshot;
  // Over iOS13, snapshot returns a child.
  // The purpose of here is return a single element to replace children with an empty array for testing.
  snapshot.children = @[];
  return snapshot;
}

- (void)testSingleDescendantXMLRepresentation
{
  id<FBXCElementSnapshot> snapshot = self.destinationSnapshot;
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  NSString *xmlStr = [FBXPath xmlStringWithRootElement:wrappedSnapshot
                                               options:nil];
  XCTAssertNotNil(xmlStr);
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\"/>\n", wrappedSnapshot.wdType, wrappedSnapshot.wdType, wrappedSnapshot.wdName, wrappedSnapshot.wdLabel, FBBoolToString(wrappedSnapshot.wdEnabled), FBBoolToString(wrappedSnapshot.wdVisible), FBBoolToString(wrappedSnapshot.wdAccessible), [wrappedSnapshot.wdRect[@"x"] stringValue], [wrappedSnapshot.wdRect[@"y"] stringValue], [wrappedSnapshot.wdRect[@"width"] stringValue], [wrappedSnapshot.wdRect[@"height"] stringValue], wrappedSnapshot.wdIndex];
  XCTAssertEqualObjects(xmlStr, expectedXml);
}

- (void)testSingleDescendantXMLRepresentationWithScope
{
  id<FBXCElementSnapshot> snapshot = self.destinationSnapshot;
  NSString *scope = @"AppiumAUT";
  FBXMLGenerationOptions *options = [[FBXMLGenerationOptions new] withScope:scope];
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  NSString *xmlStr = [FBXPath xmlStringWithRootElement:wrappedSnapshot
                                               options:options];
  XCTAssertNotNil(xmlStr);
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@>\n  <%@ type=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\"/>\n</%@>\n", scope, wrappedSnapshot.wdType, wrappedSnapshot.wdType, wrappedSnapshot.wdName, wrappedSnapshot.wdLabel, FBBoolToString(wrappedSnapshot.wdEnabled), FBBoolToString(wrappedSnapshot.wdVisible), FBBoolToString(wrappedSnapshot.wdAccessible), [wrappedSnapshot.wdRect[@"x"] stringValue], [wrappedSnapshot.wdRect[@"y"] stringValue], [wrappedSnapshot.wdRect[@"width"] stringValue], [wrappedSnapshot.wdRect[@"height"] stringValue], wrappedSnapshot.wdIndex, scope];
  XCTAssertEqualObjects(xmlStr, expectedXml);
}

- (void)testSingleDescendantXMLRepresentationWithoutAttributes
{
  id<FBXCElementSnapshot> snapshot = self.destinationSnapshot;
  FBXMLGenerationOptions *options = [[FBXMLGenerationOptions new]
                                     withExcludedAttributes:@[@"visible", @"enabled", @"index", @"blabla"]];
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  NSString *xmlStr = [FBXPath xmlStringWithRootElement:wrappedSnapshot
                                               options:options];
  XCTAssertNotNil(xmlStr);
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" name=\"%@\" label=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\"/>\n", wrappedSnapshot.wdType, wrappedSnapshot.wdType, wrappedSnapshot.wdName, wrappedSnapshot.wdLabel, FBBoolToString(wrappedSnapshot.wdAccessible), [wrappedSnapshot.wdRect[@"x"] stringValue], [wrappedSnapshot.wdRect[@"y"] stringValue], [wrappedSnapshot.wdRect[@"width"] stringValue], [wrappedSnapshot.wdRect[@"height"] stringValue]];
  XCTAssertEqualObjects(xmlStr, expectedXml);
}

- (void)testFindMatchesInElement
{
  NSArray<id<FBXCElementSnapshot>> *matchingSnapshots = [FBXPath matchesWithRootElement:self.testedApplication forQuery:@"//XCUIElementTypeButton"];
  XCTAssertEqual([matchingSnapshots count], 5);
  for (id<FBXCElementSnapshot> element in matchingSnapshots) {
    XCTAssertTrue([[FBXCElementSnapshotWrapper ensureWrapped:element].wdType isEqualToString:@"XCUIElementTypeButton"]);
  }
}

- (void)testFindMatchesInElementWithDotNotation
{
  NSArray<id<FBXCElementSnapshot>> *matchingSnapshots = [FBXPath matchesWithRootElement:self.testedApplication forQuery:@".//XCUIElementTypeButton"];
  XCTAssertEqual([matchingSnapshots count], 5);
  for (id<FBXCElementSnapshot> element in matchingSnapshots) {
    XCTAssertTrue([[FBXCElementSnapshotWrapper ensureWrapped:element].wdType isEqualToString:@"XCUIElementTypeButton"]);
  }
}

@end
