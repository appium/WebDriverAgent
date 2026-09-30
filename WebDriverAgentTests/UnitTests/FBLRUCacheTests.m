/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "LRUCache.h"

@interface FBLRUCacheTests : XCTestCase
@end

@implementation FBLRUCacheTests

- (void)testDestroyingCacheReleasesAllValues
{
  __weak NSObject *firstValue;
  __weak NSObject *secondValue;
  @autoreleasepool {
    LRUCache *cache = [[LRUCache alloc] initWithCapacity:2];
    NSObject *first = [NSObject new];
    NSObject *second = [NSObject new];
    firstValue = first;
    secondValue = second;
    [cache setObject:first forKey:@"first"];
    [cache setObject:second forKey:@"second"];
    XCTAssertNotNil([cache objectForKey:@"first"]);
  }
  XCTAssertNil(firstValue);
  XCTAssertNil(secondValue);
}

- (void)testRemovingValueReleasesItWhileCacheRemainsAlive
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:3];
  __weak NSObject *removedValue;
  @autoreleasepool {
    NSObject *value = [NSObject new];
    removedValue = value;
    [cache setObject:@"oldest" forKey:@"oldest"];
    [cache setObject:value forKey:@"removed"];
    [cache setObject:@"newest" forKey:@"newest"];
    [cache removeObjectForKey:@"removed"];
  }
  XCTAssertNil(removedValue);
  XCTAssertEqualObjects(cache.allObjects, (@[@"newest", @"oldest"]));
}

- (void)assertArray:(NSArray *)array1 equalsTo:(NSArray *)array2
{
  XCTAssertEqualObjects(array1, array2);
}

- (void)testRecentlyInsertedObjectReplacesTheOldestOne
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:1];
  [cache setObject:@"foo" forKey:@"bar"];
  [cache setObject:@"foo2" forKey:@"bar2"];
  [cache setObject:@"foo3" forKey:@"bar3"];
  XCTAssertEqualObjects(@[@"foo3"], cache.allObjects);
}

- (void)testRecentObjectReplacementAndBump
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:2];
  [cache setObject:@"foo" forKey:@"bar"];
  [cache setObject:@"foo2" forKey:@"bar2"];
  [self assertArray:@[@"foo2", @"foo"] equalsTo:cache.allObjects];
  XCTAssertNotNil([cache objectForKey:@"bar"]);
  [self assertArray:@[@"foo", @"foo2"] equalsTo:cache.allObjects];
  [cache setObject:@"foo3" forKey:@"bar3"];
  [self assertArray:@[@"foo3", @"foo"] equalsTo:cache.allObjects];
  [cache setObject:@"foo0" forKey:@"bar"];
  [self assertArray:@[@"foo0", @"foo3"] equalsTo:cache.allObjects];
  [cache setObject:@"foo4" forKey:@"bar4"];
  [self assertArray:@[@"foo4", @"foo0"] equalsTo:cache.allObjects];
}

- (void)testBumpFromHead
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:3];
  [cache setObject:@"foo" forKey:@"bar"];
  [cache setObject:@"foo2" forKey:@"bar2"];
  [cache setObject:@"foo3" forKey:@"bar3"];
  XCTAssertNotNil([cache objectForKey:@"bar3"]);
  [self assertArray:@[@"foo3", @"foo2", @"foo"] equalsTo:cache.allObjects];
  [cache setObject:@"foo4" forKey:@"bar4"];
  [cache setObject:@"foo5" forKey:@"bar5"];
  [self assertArray:@[@"foo5", @"foo4", @"foo3"] equalsTo:cache.allObjects];
}

- (void)testBumpFromMiddle
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:3];
  [cache setObject:@"foo" forKey:@"bar"];
  [cache setObject:@"foo2" forKey:@"bar2"];
  [cache setObject:@"foo3" forKey:@"bar3"];
  XCTAssertNotNil([cache objectForKey:@"bar2"]);
  [self assertArray:@[@"foo2", @"foo3", @"foo"] equalsTo:cache.allObjects];
  [cache setObject:@"foo4" forKey:@"bar4"];
  [cache setObject:@"foo5" forKey:@"bar5"];
  [self assertArray:@[@"foo5", @"foo4", @"foo2"] equalsTo:cache.allObjects];
}

- (void)testBumpFromTail
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:3];
  [cache setObject:@"foo" forKey:@"bar"];
  [cache setObject:@"foo2" forKey:@"bar2"];
  [cache setObject:@"foo3" forKey:@"bar3"];
  XCTAssertNotNil([cache objectForKey:@"bar3"]);
  [self assertArray:@[@"foo3", @"foo2", @"foo"] equalsTo:cache.allObjects];
  [cache setObject:@"foo4" forKey:@"bar4"];
  [cache setObject:@"foo5" forKey:@"bar5"];
  [self assertArray:@[@"foo5", @"foo4", @"foo3"] equalsTo:cache.allObjects];
}

- (void)testInsertionLoop
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:1];
  NSUInteger count = 100;
  for (NSUInteger i = 0; i <= count; ++i) {
    [cache setObject:@(i) forKey:@(i)];
    XCTAssertNotNil([cache objectForKey:@(i)]);
  }
  XCTAssertEqualObjects(@[@(count)], cache.allObjects);
}

- (void)testRemoveExistingObjectForKey {
    LRUCache *cache = [[LRUCache alloc] initWithCapacity:3];
    [cache setObject:@"foo" forKey:@"bar"];
    [cache setObject:@"foo2" forKey:@"bar2"];
    [cache setObject:@"foo3" forKey:@"bar3"];
    [self assertArray:@[@"foo3", @"foo2", @"foo"] equalsTo:cache.allObjects];
    [cache removeObjectForKey:@"bar2"];
    XCTAssertNil([cache objectForKey:@"bar2"]);
    [self assertArray:@[@"foo3", @"foo"] equalsTo:cache.allObjects];
}

- (void)testRemoveNonExistingObjectForKey {
    LRUCache *cache = [[LRUCache alloc] initWithCapacity:2];
    [cache setObject:@"foo" forKey:@"bar"];
    [cache removeObjectForKey:@"nonExisting"];
    XCTAssertNotNil([cache objectForKey:@"bar"]);
    [self assertArray:@[@"foo"] equalsTo:cache.allObjects];
}

- (void)testRemoveAndInsertFlow {
    LRUCache *cache = [[LRUCache alloc] initWithCapacity:2];
    [cache setObject:@"foo" forKey:@"bar"];
    [cache setObject:@"foo2" forKey:@"bar2"];
    [cache removeObjectForKey:@"bar"];
    XCTAssertNil([cache objectForKey:@"bar"]);
    [cache setObject:@"foo3" forKey:@"bar3"];
    [self assertArray:@[@"foo3", @"foo2"] equalsTo:cache.allObjects];
}

@end
