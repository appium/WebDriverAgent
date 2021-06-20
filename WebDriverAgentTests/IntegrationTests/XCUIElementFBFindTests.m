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
#import "FBElementUtils.h"
#import "FBExceptions.h"
#import "FBTestMacros.h"
#import "XCUIElement.h"
#import "XCUIElement+FBFind.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBResolve.h"
#import "FBXPath.h"
#import "FBXCodeCompatibility.h"

@interface XCUIElementFBFindTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *testedView;
@end

@implementation XCUIElementFBFindTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
  });
  self.testedView = self.testedApplication.otherElements[@"MainView"];
  FBAssertWaitTillBecomesTrue(self.testedView.exists);
}

- (void)testDescendantsWithClassName
{
  NSSet<NSString *> *expectedLabels = [NSSet setWithArray:@[
    @"Alerts",
    @"Attributes",
    @"Scrolling",
    @"Deadlock app",
    @"Touch",
  ]];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingClassName:@"XCUIElementTypeButton" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, expectedLabels.count);
  NSArray<NSString *> *labels = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.label"];
  XCTAssertEqualObjects([NSSet setWithArray:labels], expectedLabels);

  NSArray<NSNumber *> *types = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.elementType"];
  XCTAssertEqual(types.count, 1, @"matchingSnapshots should contain only one type");
  XCTAssertEqualObjects(types.lastObject, @(XCUIElementTypeButton), @"matchingSnapshots should contain only one type");
}

- (void)testSingleDescendantWithClassName
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingClassName:@"XCUIElementTypeButton" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
}

- (void)testDescendantsWithIdentifier
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingIdentifier:@"Alerts" shouldReturnAfterFirstMatch:NO];
  int snapshotsCount = 1;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 2;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
  XCTAssertEqual(matchingSnapshots.firstObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
  NSArray<XCUIElement *> *selfElementsById = [matchingSnapshots.lastObject fb_descendantsMatchingIdentifier:@"Alerts" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(selfElementsById.count, 1);
}

- (void)testSingleDescendantWithIdentifier
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingIdentifier:@"Alerts" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testStableInstance
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingIdentifier:@"Alerts" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 1);
  for (XCUIElement *el in @[matchingSnapshots.lastObject, matchingSnapshots.lastObject.fb_stableInstance]) {
    XCTAssertEqual(el.elementType, XCUIElementTypeButton);
    XCTAssertEqualObjects(el.label, @"Alerts");
  }
}

- (void)testSingleDescendantWithMissingIdentifier
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingIdentifier:@"blabla" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 0);
}

- (void)testDescendantsWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@label='Alerts']" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testSelfWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeApplication" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeApplication);
}

- (void)testSingleDescendantWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCUIElement *matchingSnapshot = [matchingSnapshots firstObject];
  XCTAssertNotNil(matchingSnapshot);
  XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshot.label, @"Alerts");
}

- (void)testSingleDescendantWithXPathQueryNoMatches
{
  XCUIElement *matchingSnapshot = [[self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButtonnn" shouldReturnAfterFirstMatch:YES] firstObject];
  XCTAssertNil(matchingSnapshot);
}

- (void)testSingleLastDescendantWithXPathQuery
{
  XCUIElement *matchingSnapshot = [[self.testedView fb_descendantsMatchingXPathQuery:@"(//XCUIElementTypeButton)[last()]" shouldReturnAfterFirstMatch:YES] firstObject];
  XCTAssertNotNil(matchingSnapshot);
  XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
}

- (void)testDescendantsWithXPathQueryNoMatches
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@label='Alerts1']" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 0);
}

- (void)testDescendantsWithComplexXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//*[@label='Scrolling']/preceding::*[boolean(string(@label))]" shouldReturnAfterFirstMatch:NO];
  int snapshotsCount = 3;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 6;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
}

- (void)testDescendantsWithWrongXPathQuery
{
  XCTAssertThrowsSpecificNamed([self.testedView fb_descendantsMatchingXPathQuery:@"//*[blabla(@label, Scrolling')]" shouldReturnAfterFirstMatch:NO],
                               NSException, FBInvalidXPathException);
}

- (void)testFirstDescendantWithWrongXPathQuery
{
  XCTAssertThrowsSpecificNamed([self.testedView fb_descendantsMatchingXPathQuery:@"//*[blabla(@label, Scrolling')]" shouldReturnAfterFirstMatch:YES],
                               NSException, FBInvalidXPathException);
}

- (void)testVisibleDescendantWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@name='Alerts' and @enabled='true' and @visible='true']" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertTrue(matchingSnapshots.lastObject.isEnabled);
  XCTAssertTrue(matchingSnapshots.lastObject.fb_isVisible);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithPredicateString
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label = 'Alerts'"];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingPredicate:predicate shouldReturnAfterFirstMatch:NO];
  int snapshotsCount = 1;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 2;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
  XCTAssertEqual(matchingSnapshots.firstObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
  NSPredicate *selfPredicate = [NSPredicate predicateWithFormat:@"label == 'Alerts'"];
  NSArray<XCUIElement *> *selfElementsByPredicate = [matchingSnapshots.lastObject fb_descendantsMatchingPredicate:selfPredicate shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(selfElementsByPredicate.count, 1);
}

- (void)testSelfWithPredicateString
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == 'XCUIElementTypeApplication'"];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingPredicate:predicate shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeApplication);
}

- (void)testSingleDescendantWithPredicateString
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type = 'XCUIElementTypeButton'"];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingPredicate:predicate shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
}

- (void)testSingleDescendantWithPredicateStringByIndex
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == 'XCUIElementTypeButton' AND index == 2"];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingPredicate:predicate shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
}

- (void)testDescendantsWithPropertyStrict
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alert" partialSearch:NO];
  XCTAssertEqual(matchingSnapshots.count, 0);
  matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alerts" partialSearch:NO];
  int snapshotsCount = 1;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 2;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
  XCTAssertEqual(matchingSnapshots.firstObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testGlobalWithPropertyStrict
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingProperty:@"label" value:@"Alert" partialSearch:NO];
  XCTAssertEqual(matchingSnapshots.count, 0);
  matchingSnapshots = [self.testedApplication fb_descendantsMatchingProperty:@"label" value:@"Alerts" partialSearch:NO];
  int snapshotsCount = 1;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 2;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
  XCTAssertEqual(matchingSnapshots.firstObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithPropertyPartial
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alerts" partialSearch:NO];
  int snapshotsCount = 1;
  if (@available(iOS 13.0, *)) {
    snapshotsCount = 2;
  }
  XCTAssertEqual(matchingSnapshots.count, snapshotsCount);
  XCTAssertEqual(matchingSnapshots.firstObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithClassChain
{
  NSArray<XCUIElement *> *matchingSnapshots;
  NSString *queryString =@"XCUIElementTypeWindow/XCUIElementTypeOther/**/XCUIElementTypeButton";
  matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 5); // /XCUIElementTypeButton
  for (XCUIElement *matchingSnapshot in matchingSnapshots) {
    XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
  }
}

- (void)testDescendantsWithClassChainWithIndex
{
  NSArray<XCUIElement *> *matchingSnapshots;
  NSString *queryString = @"XCUIElementTypeWindow/*/*[2]/*/*/XCUIElementTypeButton";
  if (@available(iOS 13.0, *)) {
    // iPhone
    queryString = @"XCUIElementTypeWindow/*/*/*/*[2]/*/*/XCUIElementTypeButton";
    matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
    if (matchingSnapshots.count == 0) {
      // iPad
      queryString = @"XCUIElementTypeWindow/*/*/*/*/*[2]/*/*/XCUIElementTypeButton";
      matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
    }
  } else {
    matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  }
  XCTAssertEqual(matchingSnapshots.count, 5); // /XCUIElementTypeButton
  for (XCUIElement *matchingSnapshot in matchingSnapshots) {
    XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
  }
}

- (void)testDescendantsWithClassChainAndPredicates
{
  NSArray<XCUIElement *> *matchingSnapshots;
  NSString *queryString = @"XCUIElementTypeWindow/**/XCUIElementTypeButton[`label BEGINSWITH 'A'`]";
  matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 2);
  XCTAssertEqualObjects([matchingSnapshots firstObject].label, @"Alerts");
  XCTAssertEqualObjects([matchingSnapshots lastObject].label, @"Attributes");
}

- (void)testDescendantsWithIndirectClassChainAndPredicates
{
  NSString *queryString = @"XCUIElementTypeWindow/**/XCUIElementTypeButton[`label BEGINSWITH 'A'`]";
  NSArray<XCUIElement *> *simpleQueryMatches = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  NSArray<XCUIElement *> *deepQueryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"XCUIElementTypeWindow/**/XCUIElementTypeButton[`label BEGINSWITH 'A'`]" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(simpleQueryMatches.count, deepQueryMatches.count);
  XCTAssertEqualObjects([simpleQueryMatches firstObject].label, [deepQueryMatches firstObject].label);
  XCTAssertEqualObjects([simpleQueryMatches lastObject].label, [deepQueryMatches lastObject].label);
}

- (void)testClassChainWithDescendantPredicate
{
  NSArray<XCUIElement *> *simpleQueryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"XCUIElementTypeWindow/*/*[2]" shouldReturnAfterFirstMatch:NO];
  NSArray<XCUIElement *> *predicateQueryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"XCUIElementTypeWindow/*/*[$type == 'XCUIElementTypeButton' AND label BEGINSWITH 'A'$]" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(simpleQueryMatches.count, predicateQueryMatches.count);
  XCTAssertEqual([simpleQueryMatches firstObject].elementType, [predicateQueryMatches firstObject].elementType);
  XCTAssertEqual([simpleQueryMatches lastObject].elementType, [predicateQueryMatches lastObject].elementType);
}

- (void)testSingleDescendantWithComplexIndirectClassChain
{
  NSArray<XCUIElement *> *queryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"**/*/XCUIElementTypeButton[2]" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(queryMatches.count, 1);
  XCTAssertEqual(queryMatches.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(queryMatches.lastObject.label, @"Deadlock app");
}

- (void)testSingleDescendantWithComplexIndirectClassChainAndZeroMatches
{
  NSArray<XCUIElement *> *queryMatches = [self.testedApplication fb_descendantsMatchingClassChain:@"**/*/XCUIElementTypeWindow" shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(queryMatches.count, 0);
}

- (void)testDescendantsWithClassChainAndPredicatesAndIndexes
{
  NSArray<XCUIElement *> *matchingSnapshots;
  NSString *queryString = @"XCUIElementTypeWindow[`name != 'bla'`]/**/XCUIElementTypeButton[`label BEGINSWITH \"A\"`][1]";
  matchingSnapshots = [self.testedApplication fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqualObjects([matchingSnapshots firstObject].label, @"Alerts");
}

- (void)testSingleDescendantWithClassChain
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingClassChain:@"XCUIElementTypeButton" shouldReturnAfterFirstMatch:YES];
  
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertTrue([matchingSnapshots.lastObject.label isEqualToString:@"Alerts"]);
}

- (void)testSingleDescendantWithClassChainAndNegativeIndex
{
  NSArray<XCUIElement *> *matchingSnapshots;
  matchingSnapshots = [self.testedView fb_descendantsMatchingClassChain:@"XCUIElementTypeButton[-1]" shouldReturnAfterFirstMatch:YES];
  
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertTrue([matchingSnapshots.lastObject.label isEqualToString:@"Touch"]);
  
  matchingSnapshots = [self.testedView fb_descendantsMatchingClassChain:@"XCUIElementTypeButton[-10]" shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 0);
}

- (void)testInvalidQueryWithClassChain
{
  XCTAssertThrowsSpecificNamed([self.testedView fb_descendantsMatchingClassChain:@"NoXCUIElementTypePrefix" shouldReturnAfterFirstMatch:YES],
                               NSException, FBClassChainQueryParseException);
}

- (void)testHandleInvalidQueryWithClassChainAsNoElementWithoutError
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView
                                               fb_descendantsMatchingClassChain:@"XCUIElementTypeBlabla"
                                               shouldReturnAfterFirstMatch:YES];
  XCTAssertEqual(matchingSnapshots.count, 0);
}

- (void)testClassChainWithInvalidPredicate
{
  XCTAssertThrowsSpecificNamed([self.testedApplication fb_descendantsMatchingClassChain:@"XCUIElementTypeWindow[`bla != 'bla'`]" shouldReturnAfterFirstMatch:NO],
                               NSException, FBUnknownAttributeException);;
}

@end

@interface XCUIElementFBFindTests_AttributesPage : FBIntegrationTestCase
@end
@implementation XCUIElementFBFindTests_AttributesPage

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAttributesPage];
  });
}

- (void)testNestedQueryWithClassChain
{
  NSString *queryString = @"XCUIElementTypeOther";
  if (@available(iOS 13.0, *)) {
    queryString = @"XCUIElementTypePicker";
  }
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Button"].fb_isVisible);
  XCUIElement *datePicker = [self.testedApplication descendantsMatchingType:XCUIElementTypeDatePicker].fb_firstMatch;
  NSArray<XCUIElement *> *matches = [datePicker fb_descendantsMatchingClassChain:queryString shouldReturnAfterFirstMatch:NO];
  XCTAssertEqual(matches.count, 1);

  XCUIElementType expectedType = XCUIElementTypeOther;
  if (@available(iOS 13.0, *)) {
    expectedType = XCUIElementTypePicker;
  }
  XCTAssertEqual([matches firstObject].elementType, expectedType);
}

@end

@interface XCUIElementFBFindTests_ScrollPage : FBIntegrationTestCase
@end
@implementation XCUIElementFBFindTests_ScrollPage

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToScrollPageWithCells:YES];
  });
}

- (void)testInvisibleDescendantWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeStaticText[@visible='false']" shouldReturnAfterFirstMatch:NO];
  XCTAssertGreaterThan(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeStaticText);
  XCTAssertFalse(matchingSnapshots.lastObject.fb_isVisible);
}

@end
