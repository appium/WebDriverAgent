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
  id<FBXCElementSnapshot> snapshot = [matchingElement fb_customSnapshot];
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

- (void)testFindMatchesWithoutContextScopeLimit
{
  XCUIElement *button = self.testedApplication.buttons.firstMatch;
  BOOL previousValue = FBConfiguration.limitXpathContextScope;
  FBConfiguration.limitXpathContextScope = NO;
  @try {
    NSArray *parentSnapshots = [FBXPath matchesWithRootElement:button forQuery:@".."];
    XCTAssertEqual(parentSnapshots.count, 1);
    XCTAssertEqualObjects(
                          [FBXCElementSnapshotWrapper ensureWrapped:[parentSnapshots objectAtIndex:0]].wdLabel,
                          @"MainView"
                          );
    NSArray *elements = [button.application fb_filterDescendantsWithSnapshots:parentSnapshots onlyChildren:NO];
    XCTAssertEqual(elements.count, 1);
    XCTAssertEqualObjects(
                          [[elements objectAtIndex:0] wdLabel],
                          @"MainView"
                          );
    NSArray *currentSnapshots = [FBXPath matchesWithRootElement:button forQuery:@"."];
    XCTAssertEqual(currentSnapshots.count, 1);
    XCTAssertEqualObjects(
                          [FBXCElementSnapshotWrapper ensureWrapped:[currentSnapshots objectAtIndex:0]].wdType,
                          @"XCUIElementTypeButton"
                          );
    NSArray *currentElements = [button.application fb_filterDescendantsWithSnapshots:currentSnapshots onlyChildren:NO];
    XCTAssertEqual(currentElements.count, 1);
    XCTAssertEqualObjects(
                          [[currentElements objectAtIndex:0] wdType],
                          @"XCUIElementTypeButton"
                          );
  } @finally {
    FBConfiguration.limitXpathContextScope = previousValue;
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
