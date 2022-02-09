/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */


#import "XCUIElement+FBFind.h"

#import "FBMacros.h"
#import "FBElementTypeTransformer.h"
#import "FBPredicate.h"
#import "NSPredicate+FBFormat.h"
#import "XCElementSnapshot.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"
#import "FBElementUtils.h"
#import "FBXCodeCompatibility.h"
#import "FBXPath.h"

@implementation XCUIElement (FBFind)

+ (NSArray<XCUIElement *> *)fb_extractMatchingElementsFromQuery:(XCUIElementQuery *)query
                                    shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  if (!shouldReturnAfterFirstMatch) {
    return query.fb_allMatches;
  }
  XCUIElement *matchedElement = query.fb_firstMatch;
  return matchedElement ? @[matchedElement] : @[];
}

- (XCElementSnapshot *)fb_cachedSnapshotWithQuery:(XCUIElementQuery *)query
{
  return [self isKindOfClass:XCUIApplication.class] ? query.rootElementSnapshot : self.fb_cachedSnapshot;
}

#pragma mark - Search by ClassName

- (NSArray<XCUIElement *> *)fb_descendantsMatchingClassName:(NSString *)className
                                shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  XCUIElementType type = [FBElementTypeTransformer elementTypeWithTypeName:className];
  XCUIElementQuery *query = [self.fb_query descendantsMatchingType:type];
  NSMutableArray *result = [NSMutableArray array];
  [result addObjectsFromArray:[self.class fb_extractMatchingElementsFromQuery:query shouldReturnAfterFirstMatch:shouldReturnAfterFirstMatch]];
  XCElementSnapshot *cachedSnapshot = [self fb_cachedSnapshotWithQuery:query];
  if (type == XCUIElementTypeAny || cachedSnapshot.elementType == type) {
    if (shouldReturnAfterFirstMatch || result.count == 0) {
      return @[self];
    }
    [result insertObject:self atIndex:0];
  }
  return result.copy;
}


#pragma mark - Search by property value

- (NSArray<XCUIElement *> *)fb_descendantsMatchingProperty:(NSString *)property
                                                     value:(NSString *)value
                                             partialSearch:(BOOL)partialSearch
{
  NSMutableArray *elements = [NSMutableArray array];
  [self descendantsWithProperty:property value:value partial:partialSearch results:elements];
  return elements;
}

- (void)descendantsWithProperty:(NSString *)property value:(NSString *)value partial:(BOOL)partialSearch results:(NSMutableArray<XCUIElement *> *)results
{
  if (partialSearch) {
    NSString *text = [self fb_valueForWDAttributeName:property];
    BOOL isString = [text isKindOfClass:[NSString class]];
    if (isString && [text rangeOfString:value].location != NSNotFound) {
      [results addObject:self];
    }
  } else {
    if ([[self fb_valueForWDAttributeName:property] isEqual:value]) {
      [results addObject:self];
    }
  }

  property = [FBElementUtils wdAttributeNameForAttributeName:property];
  value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
  NSString *operation = partialSearch ?
  [NSString stringWithFormat:@"%@ like '*%@*'", property, value] :
  [NSString stringWithFormat:@"%@ == '%@'", property, value];

  NSPredicate *predicate = [FBPredicate predicateWithFormat:operation];
  XCUIElementQuery *query = [[self.fb_query descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:predicate];
  NSArray *childElements = query.fb_allMatches;
  [results addObjectsFromArray:childElements];
}


#pragma mark - Search by Predicate String

- (NSArray<XCUIElement *> *)fb_descendantsMatchingPredicate:(NSPredicate *)predicate
                                shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSPredicate *formattedPredicate = [NSPredicate fb_formatSearchPredicate:predicate];
  XCUIElementQuery *query = [[self.fb_query descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:formattedPredicate];
  NSMutableArray<XCUIElement *> *result = [NSMutableArray array];
  [result addObjectsFromArray:[self.class fb_extractMatchingElementsFromQuery:query
                                                  shouldReturnAfterFirstMatch:shouldReturnAfterFirstMatch]];
  XCElementSnapshot *cachedSnapshot = [self fb_cachedSnapshotWithQuery:query];
  // Include self element into predicate search
  if ([formattedPredicate evaluateWithObject:cachedSnapshot]) {
    if (shouldReturnAfterFirstMatch || result.count == 0) {
      return @[self];
    }
    [result insertObject:self atIndex:0];
  }
  return result.copy;
}


#pragma mark - Search by xpath

- (NSArray<XCUIElement *> *)fb_descendantsMatchingXPathQuery:(NSString *)xpathQuery
                                 shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  // XPath will try to match elements only class name, so requesting elements by XCUIElementTypeAny will not work. We should use '*' instead.
  xpathQuery = [xpathQuery stringByReplacingOccurrencesOfString:@"XCUIElementTypeAny" withString:@"*"];
  NSArray<XCElementSnapshot *> *matchingSnapshots = [FBXPath matchesWithRootElement:self forQuery:xpathQuery];
  if (0 == [matchingSnapshots count]) {
    return @[];
  }
  if (shouldReturnAfterFirstMatch) {
    XCElementSnapshot *snapshot = matchingSnapshots.firstObject;
    matchingSnapshots = @[snapshot];
  }
  return [self fb_filterDescendantsWithSnapshots:matchingSnapshots
                                         selfUID:self.lastSnapshot.wdUID
                                    onlyChildren:NO];
}


#pragma mark - Search by Accessibility Id

- (NSArray<XCUIElement *> *)fb_descendantsMatchingIdentifier:(NSString *)accessibilityId
                                 shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSPredicate *predicate = [FBPredicate predicateWithFormat:@"name == %@", accessibilityId];
  return [self fb_descendantsMatchingPredicate:predicate
                   shouldReturnAfterFirstMatch:shouldReturnAfterFirstMatch];
}

@end
