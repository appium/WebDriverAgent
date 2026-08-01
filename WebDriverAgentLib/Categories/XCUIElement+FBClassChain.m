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

// Walks a single upfront snapshot of `self` in memory to resolve every
// non-indexed chain segment, instead of resolving an intermediate live
// XCUIElement (and paying an accessibility round trip) just to obtain a
// query root for the next segment. A live element is only ever resolved
// once, for the final match(es), via a uid-predicate lookup.
- (NSArray<XCUIElement *> *)fb_descendantsMatchingClassChain:(NSString *)classChainQuery shouldReturnAfterFirstMatch:(BOOL)shouldReturnAfterFirstMatch
{
  NSError *error;
  FBClassChain *parsedChain = [FBClassChainQueryParser parseQuery:classChainQuery error:&error];
  if (nil == parsedChain) {
    @throw [NSException exceptionWithName:FBClassChainQueryParseException reason:error.localizedDescription userInfo:error.userInfo];
    return nil;
  }
  NSMutableArray<FBClassChainItem *> *lookupChain = parsedChain.elements.mutableCopy;
  NSArray<id<FBXCElementSnapshot>> *currentRoots = @[[self fb_customSnapshot]];
  FBClassChainItem *chainItem = lookupChain.firstObject;
  NSArray<id<FBXCElementSnapshot>> *candidates = [self.class fb_snapshotsMatchingItem:chainItem inRoots:currentRoots];
  [lookupChain removeObjectAtIndex:0];
  while (lookupChain.count > 0) {
    if (nil != chainItem.position) {
      // It is necessary to resolve the position if intermediate element index is not zero or one,
      // because predicates don't support search by indexes
      NSArray<id<FBXCElementSnapshot>> *currentRootMatch = [self.class fb_matchingSnapshotsWithItem:chainItem
                                                                                           candidates:candidates
                                                                          shouldReturnAfterFirstMatch:nil];
      if (0 == currentRootMatch.count) {
        return @[];
      }
      currentRoots = @[currentRootMatch.firstObject];
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
