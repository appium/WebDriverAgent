/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "LRUCache.h"

@interface FBLRUCacheTests : XCTestCase
@end

@implementation FBLRUCacheTests

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
  XCTAssertNotNil([cache objectForKey:@"bar"]);
  [cache setObject:@"foo3" forKey:@"bar3"];
  XCTAssertTrue([cache.allObjects containsObject:@"foo"]);
  XCTAssertTrue([cache.allObjects containsObject:@"foo3"]);
  XCTAssertFalse([cache.allObjects containsObject:@"foo2"]);
  [cache setObject:@"foo0" forKey:@"bar"];
  XCTAssertFalse([cache.allObjects containsObject:@"foo"]);
  XCTAssertTrue([cache.allObjects containsObject:@"foo3"]);
  XCTAssertTrue([cache.allObjects containsObject:@"foo0"]);
  XCTAssertFalse([cache.allObjects containsObject:@"foo2"]);
  [cache setObject:@"foo4" forKey:@"bar4"];
  XCTAssertEqual(cache.allObjects.count, 2);
  XCTAssertTrue([cache.allObjects containsObject:@"foo4"]);
  XCTAssertTrue([cache.allObjects containsObject:@"foo0"]);
  XCTAssertFalse([cache.allObjects containsObject:@"foo"]);
  XCTAssertFalse([cache.allObjects containsObject:@"foo2"]);
  XCTAssertFalse([cache.allObjects containsObject:@"foo3"]);
}

- (void)testInsertionLoop
{
  LRUCache *cache = [[LRUCache alloc] initWithCapacity:1];
  NSUInteger count = 100;
  for (NSUInteger i = 0; i <= count; ++i) {
    [cache setObject:@(i) forKey:@(i)];
  }
  XCTAssertEqualObjects(@[@(count)], cache.allObjects);
}

@end
