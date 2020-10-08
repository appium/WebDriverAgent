/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBClassChain.h"

#import "FBClassChainQueryParser.h"
#import "FBXCodeCompatibility.h"
#import "FBExceptions.h"

@implementation XCUIElement (FBClassChain)

- (NSArray<XCUIElement *> *)fb_descendantsMatchingClassChain:(NSString *)classChainQuery shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSError *error;
  FBClassChain *parsedChain = [FBClassChainQueryParser parseQuery:classChainQuery error:&error];
  if (nil == parsedChain) {
    @throw [NSException exceptionWithName:FBClassChainQueryParseException reason:error.localizedDescription userInfo:error.userInfo];
    return nil;
  }
  NSMutableArray<FBClassChainItem *> *lookupChain = parsedChain.elements.mutableCopy;
  FBClassChainItem *chainItem = lookupChain.firstObject;
  XCUIElement *currentRoot = self;
  XCUIElementQuery *query = [currentRoot fb_queryWithChainItem:chainItem query:nil];
  [lookupChain removeObjectAtIndex:0];
  while (lookupChain.count > 0) {
    BOOL isRootChanged = NO;
    if (nil != chainItem.position) {
      // It is necessary to resolve the query if intermediate element index is not zero or one,
      // because predicates don't support search by indexes
      NSArray<XCUIElement *> *currentRootMatch = [self.class fb_matchingElementsWithItem:chainItem
                                                                                   query:query
                                                             shouldReturnAfterFirstMatch:nil];
      if (0 == currentRootMatch.count) {
        return @[];
      }
      currentRoot = currentRootMatch.firstObject;
      isRootChanged = YES;
    }
    chainItem = [lookupChain firstObject];
    query = [currentRoot fb_queryWithChainItem:chainItem query:isRootChanged ? nil : query];
    [lookupChain removeObjectAtIndex:0];
  }
  return [self.class fb_matchingElementsWithItem:chainItem
                                           query:query
                     shouldReturnAfterFirstMatch:@(shouldReturnAfterFirstMatch)];
}

- (XCUIElementQuery *)fb_queryWithChainItem:(FBClassChainItem *)item query:(nullable XCUIElementQuery *)query
{
  if (item.isDescendant) {
    if (query) {
      query = [query descendantsMatchingType:item.type];
    } else {
      query = [self.fb_query descendantsMatchingType:item.type];
    }
  } else {
    if (query) {
      query = [query childrenMatchingType:item.type];
    } else {
      query = [self.fb_query childrenMatchingType:item.type];
    }
  }
  if (item.predicates) {
    for (FBAbstractPredicateItem *predicate in item.predicates) {
      if ([predicate isKindOfClass:FBSelfPredicateItem.class]) {
        query = [query matchingPredicate:predicate.value];
      } else if ([predicate isKindOfClass:FBDescendantPredicateItem.class]) {
        query = [query containingPredicate:predicate.value];
      }
    }
  }
  return query;
}

+ (NSArray<XCUIElement *> *)fb_matchingElementsWithItem:(FBClassChainItem *)item query:(XCUIElementQuery *)query shouldReturnAfterFirstMatch:(nullable NSNumber *)shouldReturnAfterFirstMatch
{
  if (1 == item.position.integerValue || (0 == item.position.integerValue && shouldReturnAfterFirstMatch.boolValue)) {
    XCUIElement *result = query.fb_firstMatch;
    return result ? @[result] : @[];
  }
  NSArray<XCUIElement *> *allMatches = query.fb_allMatches;
  if (0 == item.position.integerValue) {
    return allMatches;
  }
  if (allMatches.count >= (NSUInteger)ABS(item.position.integerValue)) {
    return item.position.integerValue > 0
      ? @[[allMatches objectAtIndex:item.position.integerValue - 1]]
      : @[[allMatches objectAtIndex:allMatches.count + item.position.integerValue]];
  }
  return @[];
}

@end
