/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElementQuery+FBHelpers.h"

#import "FBXCodeCompatibility.h"
#import "XCUIElementQuery.h"
#import "FBXCElementSnapshot.h"

@implementation XCUIElementQuery (FBHelpers)

- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshot
{
  id<FBXCElementSnapshot> rootElementSnapshot = self.rootElementSnapshot;
  if (nil == rootElementSnapshot) {
    return nil;
  }

  XCUIElementQuery *inputQuery = self;
  NSMutableArray<id<XCTElementSetTransformer>> *transformersChain = [NSMutableArray array];
  while (nil != inputQuery && nil != inputQuery.transformer) {
    [transformersChain insertObject:inputQuery.transformer atIndex:0];
    inputQuery = inputQuery.inputQuery;
  }

  NSMutableArray *snapshots = [NSMutableArray arrayWithObject:rootElementSnapshot];
  [snapshots addObjectsFromArray:rootElementSnapshot._allDescendants];
  NSOrderedSet *matchingSnapshots = [NSOrderedSet orderedSetWithArray:snapshots];
  @try {
    for (id<XCTElementSetTransformer> transformer in transformersChain) {
      matchingSnapshots = (NSOrderedSet *)[transformer transform:matchingSnapshots
                                                 relatedElements:nil];
    }
    return matchingSnapshots.count == 1 ? matchingSnapshots.firstObject : nil;
  } @catch (NSException *e) {
    [FBLogger logFmt:@"Got an unexpected error while retriveing the cached snapshot: %@", e.reason];
  }
  return nil;
}

@end
