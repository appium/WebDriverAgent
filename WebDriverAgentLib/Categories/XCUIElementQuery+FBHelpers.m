/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIElementQuery+FBHelpers.h"

#import "FBXCodeCompatibility.h"
#import "XCUIElementQuery.h"
#import "FBXCElementSnapshot.h"
#import "XCTElementSetTransformer-Protocol.h"

@interface FBQuerySnapshotContext ()
@property (nonatomic) NSMapTable<id, NSOrderedSet *> *roots;
@end

@implementation FBQuerySnapshotContext
- (instancetype)init
{
  if ((self = [super init])) {
    _roots = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)
                                  valueOptions:NSPointerFunctionsStrongMemory];
  }
  return self;
}

- (NSOrderedSet *)snapshotsForRoot:(id<FBXCElementSnapshot>)root
{
  NSOrderedSet *result = [self.roots objectForKey:root];
  if (nil == result) {
    NSMutableArray *snapshots = [NSMutableArray arrayWithObject:root];
    [snapshots addObjectsFromArray:root._allDescendants];
    result = [NSOrderedSet orderedSetWithArray:snapshots];
    [self.roots setObject:result forKey:root];
  }
  return result;
}
@end

@implementation XCUIElementQuery (FBHelpers)

- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshot
{
  return [self fb_cachedSnapshotWithContext:nil];
}

- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshotWithContext:(nullable FBQuerySnapshotContext *)context
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

  NSOrderedSet *matchingSnapshots = [(context ?: [FBQuerySnapshotContext new]) snapshotsForRoot:rootElementSnapshot];
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
