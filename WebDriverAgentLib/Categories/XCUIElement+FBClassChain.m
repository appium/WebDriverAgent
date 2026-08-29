/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIElement+FBClassChain.h"

#import "FBClassChainQueryParser.h"
#import "FBXCodeCompatibility.h"
#import "FBExceptions.h"
#import "XCUIElement+FBUtilities.h"

@implementation XCUIElement (FBClassChain)

- (NSArray<XCUIElement *> *)fb_descendantsMatchingClassChain:(NSString *)classChainQuery shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSError *error;
  FBClassChain *parsedChain = [FBClassChainQueryParser parseQuery:classChainQuery error:&error];
  if (nil == parsedChain) {
    @throw [NSException exceptionWithName:FBClassChainQueryParseException reason:error.localizedDescription userInfo:error.userInfo];
    return nil;
  }
  // The snapshot-walk strategy below only pays off when an intermediate
  // (non-final) segment carries an explicit position: that is the only
  // shape where the query-based strategy has to resolve a live element
  // mid-chain - and pay an accessibility round trip - just to keep building
  // the next segment's query. Every other shape (including the common case
  // of zero or one position, on the final segment only) already resolves in
  // a single round trip with the query-based strategy, while the snapshot
  // walk always pays for one full upfront subtree snapshot regardless of
  // whether it is actually needed - a bad trade in deep/large trees. See
  // https://github.com/appium/WebDriverAgent/pull/1194#issuecomment-5156633352
  NSArray<FBClassChainItem *> *chainItems = parsedChain.elements;
  return [self.class fb_hasIntermediatePosition:chainItems]
    ? [self fb_snapshotDescendantsMatchingChainItems:chainItems shouldReturnAfterFirstMatch:shouldReturnAfterFirstMatch]
    : [self fb_queryDescendantsMatchingChainItems:chainItems shouldReturnAfterFirstMatch:shouldReturnAfterFirstMatch];
}

+ (BOOL)fb_hasIntermediatePosition:(NSArray<FBClassChainItem *> *)chainItems
{
  for (NSUInteger i = 0; i + 1 < chainItems.count; i++) {
    if (nil != chainItems[i].position) {
      return YES;
    }
  }
  return NO;
}

#pragma mark - Query-based strategy
#pragma mark (single accessibility round trip; used whenever no intermediate
#pragma mark  segment carries an explicit position)

- (NSArray<XCUIElement *> *)fb_queryDescendantsMatchingChainItems:(NSArray<FBClassChainItem *> *)chainItems shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSMutableArray<FBClassChainItem *> *lookupChain = chainItems.mutableCopy;
  FBClassChainItem *chainItem = lookupChain.firstObject;
  XCUIElement *currentRoot = self;
  XCUIElementQuery *query = [currentRoot fb_queryWithChainItem:chainItem query:nil];
  [lookupChain removeObjectAtIndex:0];
  while (lookupChain.count > 0) {
    BOOL isRootChanged = NO;
    if (nil != chainItem.position) {
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

#pragma mark - Snapshot-based strategy
#pragma mark (single upfront snapshot walked in memory; used when an
#pragma mark  intermediate segment has an explicit position, avoiding one
#pragma mark  extra accessibility round trip per such segment)

- (NSArray<XCUIElement *> *)fb_snapshotDescendantsMatchingChainItems:(NSArray<FBClassChainItem *> *)chainItems shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSMutableArray<FBClassChainItem *> *lookupChain = chainItems.mutableCopy;
  // self.lastSnapshot may be stale leftover from an unrelated earlier command.
  NSArray<id<FBXCElementSnapshot>> *currentRoots = @[self.fb_cachedSnapshot ?: [self fb_customSnapshot]];
  FBClassChainItem *chainItem = lookupChain.firstObject;
  NSArray<id<FBXCElementSnapshot>> *candidates = [self.class fb_snapshotsMatchingItem:chainItem inRoots:currentRoots];
  [lookupChain removeObjectAtIndex:0];
  while (lookupChain.count > 0) {
    if (nil != chainItem.position) {
      // An explicit position always narrows the match set down to a single
      // element, which becomes the sole root for the rest of the chain, so
      // it has to be resolved now instead of being folded into `candidates`
      // like an unindexed segment would be
      NSArray<id<FBXCElementSnapshot>> *currentRootMatch = [self.class fb_matchingSnapshotsWithItem:chainItem
                                                                                           candidates:candidates
                                                                          shouldReturnAfterFirstMatch:nil];
      if (0 == currentRootMatch.count) {
        return @[];
      }
      currentRoots = @[(id<FBXCElementSnapshot> _Nonnull)currentRootMatch.firstObject];
    } else {
      currentRoots = candidates;
    }
    chainItem = lookupChain.firstObject;
    candidates = [self.class fb_snapshotsMatchingItem:chainItem inRoots:currentRoots];
    [lookupChain removeObjectAtIndex:0];
  }
  NSArray<id<FBXCElementSnapshot>> *matchedSnapshots = [self.class fb_matchingSnapshotsWithItem:chainItem
                                                                                      candidates:candidates
                                                                     shouldReturnAfterFirstMatch:@(shouldReturnAfterFirstMatch)];
  return [self fb_filterDescendantsWithSnapshots:matchedSnapshots onlyChildren:NO];
}

+ (NSArray<id<FBXCElementSnapshot>> *)fb_snapshotsMatchingItem:(FBClassChainItem *)item inRoots:(NSArray<id<FBXCElementSnapshot>> *)roots
{
  NSMutableArray<id<FBXCElementSnapshot>> *typeMatches = [NSMutableArray array];
  for (id<FBXCElementSnapshot> root in roots) {
    if (item.isDescendant) {
      // descendantsByFilteringWithBlock: includes the receiver itself if it
      // matches the filter, unlike XCUIElementQuery's descendantsMatchingType:,
      // so the root has to be excluded explicitly here.
      [typeMatches addObjectsFromArray:[root descendantsByFilteringWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot) {
        return snapshot != root && (item.type == XCUIElementTypeAny || snapshot.elementType == item.type);
      }]];
    } else {
      for (id<FBXCElementSnapshot> child in root.children) {
        if (item.type == XCUIElementTypeAny || child.elementType == item.type) {
          [typeMatches addObject:child];
        }
      }
    }
  }
  if (roots.count > 1) {
    // Overlapping roots (e.g. a previous segment matched both an ancestor
    // and its own descendant) can otherwise yield the same snapshot twice,
    // which would skew positional selection ([2], [-1], etc.) compared to
    // the XCUIElementQuery-based matching this replaced, which always
    // operated on a de-duplicated element set.
    NSMutableArray<id<FBXCElementSnapshot>> *dedupedMatches = [NSMutableArray arrayWithCapacity:typeMatches.count];
    NSHashTable<id<FBXCElementSnapshot>> *seenMatches = [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
    for (id<FBXCElementSnapshot> match in typeMatches) {
      if (![seenMatches containsObject:match]) {
        [seenMatches addObject:match];
        [dedupedMatches addObject:match];
      }
    }
    typeMatches = dedupedMatches;
  }
  for (FBAbstractPredicateItem *predicateItem in item.predicates) {
    if ([predicateItem isKindOfClass:FBSelfPredicateItem.class]) {
      typeMatches = [[typeMatches filteredArrayUsingPredicate:predicateItem.value] mutableCopy];
    } else if ([predicateItem isKindOfClass:FBDescendantPredicateItem.class]) {
      NSMutableArray<id<FBXCElementSnapshot>> *containingMatches = [NSMutableArray array];
      for (id<FBXCElementSnapshot> candidate in typeMatches) {
        NSArray<id<FBXCElementSnapshot>> *matchingDescendants = [candidate descendantsByFilteringWithBlock:^BOOL(id<FBXCElementSnapshot> descendant) {
          return descendant != candidate && [predicateItem.value evaluateWithObject:descendant];
        }];
        if (matchingDescendants.count > 0) {
          [containingMatches addObject:candidate];
        }
      }
      typeMatches = containingMatches;
    }
  }
  return typeMatches.copy;
}

+ (NSArray<id<FBXCElementSnapshot>> *)fb_matchingSnapshotsWithItem:(FBClassChainItem *)item candidates:(NSArray<id<FBXCElementSnapshot>> *)candidates shouldReturnAfterFirstMatch:(nullable NSNumber *)shouldReturnAfterFirstMatch
{
  if (1 == item.position.integerValue || (0 == item.position.integerValue && shouldReturnAfterFirstMatch.boolValue)) {
    id<FBXCElementSnapshot> result = candidates.firstObject;
    return result ? @[result] : @[];
  }
  if (0 == item.position.integerValue) {
    return candidates;
  }
  if (candidates.count >= (NSUInteger)ABS(item.position.integerValue)) {
    return item.position.integerValue > 0
      ? @[[candidates objectAtIndex:item.position.integerValue - 1]]
      : @[[candidates objectAtIndex:candidates.count + item.position.integerValue]];
  }
  return @[];
}

@end
