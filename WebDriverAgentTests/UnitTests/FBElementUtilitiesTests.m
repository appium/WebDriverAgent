/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import <XCTest/XCTest.h>

#import "FBElement.h"
#import "XCUIElementDouble.h"
#import "FBElementUtils.h"
#import "XCUIElementQuery+FBHelpers.h"
#import "XCElementSnapshotDouble.h"

@interface FBCountedDescendantsSnapshot : XCElementSnapshotDouble
@property (nonatomic) NSUInteger descendantReads;
@end
@implementation FBCountedDescendantsSnapshot
- (NSArray *)_allDescendants { self.descendantReads++; return @[]; }
@end

@interface FBElementUtilitiesTests : XCTestCase
@end

@implementation FBElementUtilitiesTests

- (void)testSnapshotContextFlattensEachRootOnlyOnce
{
  FBQuerySnapshotContext *context = [FBQuerySnapshotContext new];
  FBCountedDescendantsSnapshot *first = [FBCountedDescendantsSnapshot new];
  FBCountedDescendantsSnapshot *next = [FBCountedDescendantsSnapshot new];
  XCTAssertEqual([context snapshotsForRoot:(id)first], [context snapshotsForRoot:(id)first]);
  XCTAssertEqual(first.descendantReads, 1u);
  XCTAssertEqual([context snapshotsForRoot:(id)next].firstObject, next);
  XCTAssertEqual(next.descendantReads, 1u);
  FBQuerySnapshotContext *nextRequest = [FBQuerySnapshotContext new];
  [nextRequest snapshotsForRoot:(id)first];
  XCTAssertEqual(first.descendantReads, 2u);
}

- (void)testSnapshotContextReleasesRootsAtTheEndOfTheRequest
{
  __weak FBCountedDescendantsSnapshot *weakRoot;
  @autoreleasepool {
    FBQuerySnapshotContext *context = [FBQuerySnapshotContext new];
    FBCountedDescendantsSnapshot *root = [FBCountedDescendantsSnapshot new];
    weakRoot = root;
    [context snapshotsForRoot:(id)root];
  }
  XCTAssertNil(weakRoot);
}

- (void)testTypesFiltering {
  NSMutableArray *elements = [NSMutableArray new];
  XCUIElementDouble *el1 = [XCUIElementDouble new];
  [elements addObject:el1];
  XCUIElementDouble *el2 = [XCUIElementDouble new];
  el2.elementType = XCUIElementTypeAlert;
  el2.wdType = @"XCUIElementTypeAlert";
  [elements addObject:el2];
  XCUIElementDouble *el3 = [XCUIElementDouble new];
  [elements addObject:el3];
  
  NSSet *result = [FBElementUtils uniqueElementTypesWithElements:elements];
  XCTAssertEqual([result count], 2);
}

@end
