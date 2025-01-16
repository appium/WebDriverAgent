/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCElementSnapshotWrapper+Helpers.h"

#import "FBFindElementCommands.h"
#import "FBErrorBuilder.h"
#import "FBRunLoopSpinner.h"
#import "FBLogger.h"
#import "FBXCElementSnapshot.h"
#import "FBXCTestDaemonsProxy.h"
#import "FBXCAXClientProxy.h"
#import "XCTestDriver.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIElement.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIHitPointResult.h"

#define ATTRIBUTE_FETCH_WARN_TIME_LIMIT 0.05

inline static BOOL isSnapshotTypeAmongstGivenTypes(id<FBXCElementSnapshot> snapshot,
                                                   NSArray<NSNumber *> *types);

@implementation FBXCElementSnapshotWrapper (Helpers)

- (NSString *)fb_description
{
  NSString *result = [NSString stringWithFormat:@"%@", self.wdType];
  if (nil != self.wdName) {
    result = [NSString stringWithFormat:@"%@ (%@)", result, self.wdName];
  }
  return result;
}

- (NSArray<id<FBXCElementSnapshot>> *)fb_descendantsMatchingType:(XCUIElementType)type
{
  return [self descendantsByFilteringWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot) {
    return snapshot.elementType == type;
  }];
}

- (id<FBXCElementSnapshot>)fb_parentMatchingType:(XCUIElementType)type
{
  NSArray *acceptedParents = @[@(type)];
  return [self fb_parentMatchingOneOfTypes:acceptedParents];
}

- (id<FBXCElementSnapshot>)fb_parentMatchingOneOfTypes:(NSArray<NSNumber *> *)types
{
  return [self fb_parentMatchingOneOfTypes:types filter:^(id<FBXCElementSnapshot> snapshot) {
    return YES;
  }];
}

- (id<FBXCElementSnapshot>)fb_parentMatchingOneOfTypes:(NSArray<NSNumber *> *)types
                                              filter:(BOOL(^)(id<FBXCElementSnapshot> snapshot))filter
{
  id<FBXCElementSnapshot> snapshot = self.parent;
  while (snapshot && !(isSnapshotTypeAmongstGivenTypes(snapshot, types) && filter(snapshot))) {
    snapshot = snapshot.parent;
  }
  return snapshot;
}

- (id)fb_attributeValue:(NSString *)attribute
                  error:(NSError **)error
{
  NSDate *start = [NSDate date];
  NSDictionary *result = [FBXCAXClientProxy.sharedClient attributesForElement:[self accessibilityElement]
                                                                   attributes:@[attribute]
                                                                        error:error];
  NSTimeInterval elapsed = ABS([start timeIntervalSinceNow]);
  if (elapsed > ATTRIBUTE_FETCH_WARN_TIME_LIMIT) {
    NSLog(@"! Fetching of %@ value for %@ took %@s", attribute, self.fb_description, @(elapsed));
  }
  return [result objectForKey:attribute];
}

inline static BOOL areValuesEqual(id value1, id value2);

inline static BOOL areValuesEqualOrBlank(id value1, id value2);

inline static BOOL isNilOrEmpty(id value);

- (BOOL)fb_framelessFuzzyMatchesElement:(id<FBXCElementSnapshot>)snapshot
{
    // Pure payload-based comparison sometimes yield false negatives, therefore relying on it only if all of the identifying properties are blank
  if (isNilOrEmpty(self.identifier)
      && isNilOrEmpty(self.title)
      && isNilOrEmpty(self.label)
      && isNilOrEmpty(self.value)
      && isNilOrEmpty(self.placeholderValue)) {
    return [self.wdUID isEqualToString:([FBXCElementSnapshotWrapper ensureWrapped:snapshot].wdUID ?: @"")];
  }
  
  // Sometimes value and placeholderValue of a correct match from different snapshots are not the same (one is nil and one is a blank string)
  // Therefore taking it into account when comparing
  return self.elementType == snapshot.elementType &&
    areValuesEqual(self.identifier, snapshot.identifier) &&
    areValuesEqual(self.title, snapshot.title) &&
    areValuesEqual(self.label, snapshot.label) &&
    areValuesEqualOrBlank(self.value, snapshot.value) &&
    areValuesEqualOrBlank(self.placeholderValue, snapshot.placeholderValue);
}

- (NSArray<id<FBXCElementSnapshot>> *)fb_descendantsCellSnapshots
{
  NSArray<id<FBXCElementSnapshot>> *cellSnapshots = [self fb_descendantsMatchingType:XCUIElementTypeCell];
  
  if (cellSnapshots.count == 0) {
    // For the home screen, cells are actually of type XCUIElementTypeIcon
    cellSnapshots = [self fb_descendantsMatchingType:XCUIElementTypeIcon];
  }
  
  if (cellSnapshots.count == 0) {
    // In some cases XCTest will not report Cell Views. In that case grab all descendants and try to figure out scroll directon from them.
    cellSnapshots = self._allDescendants;
  }
  
  return cellSnapshots;
}

- (NSArray<id<FBXCElementSnapshot>> *)fb_ancestors
{
  NSMutableArray<id<FBXCElementSnapshot>> *ancestors = [NSMutableArray array];
  id<FBXCElementSnapshot> parent = self.parent;
  while (parent) {
    [ancestors addObject:parent];
    parent = parent.parent;
  }
  return ancestors.copy;
}

- (id<FBXCElementSnapshot>)fb_parentCellSnapshot
{
  id<FBXCElementSnapshot> targetCellSnapshot = self.snapshot;
  // XCUIElementTypeIcon is the cell type for homescreen icons
  NSArray<NSNumber *> *acceptableElementTypes = @[
                                                  @(XCUIElementTypeCell),
                                                  @(XCUIElementTypeIcon),
                                                  ];
  if (self.elementType != XCUIElementTypeCell && self.elementType != XCUIElementTypeIcon) {
      targetCellSnapshot = [self fb_parentMatchingOneOfTypes:acceptableElementTypes];
  }
  return targetCellSnapshot;
}

- (NSValue *)fb_hitPoint
{
  NSError *error;
  XCUIHitPointResult *result = [self hitPoint:&error];
  if (nil != error) {
    [FBLogger logFmt:@"Failed to fetch hit point for %@ - %@", self.fb_description, error.localizedDescription];
    return nil;
  }
  return [NSValue valueWithCGPoint:result.hitPoint];
}

@end

inline static BOOL isSnapshotTypeAmongstGivenTypes(id<FBXCElementSnapshot> snapshot, NSArray<NSNumber *> *types)
{
  for (NSUInteger i = 0; i < types.count; i++) {
   if([@(snapshot.elementType) isEqual: types[i]] || [types[i] isEqual: @(XCUIElementTypeAny)]){
       return YES;
   }
  }
  return NO;
}

inline static BOOL areValuesEqual(id value1, id value2)
{
  return value1 == value2 || [value1 isEqual:value2];
}

inline static BOOL areValuesEqualOrBlank(id value1, id value2)
{
  return areValuesEqual(value1, value2) || (isNilOrEmpty(value1) && isNilOrEmpty(value2));
}

inline static BOOL isNilOrEmpty(id value)
{
  if ([value isKindOfClass:NSString.class]) {
    return [(NSString*)value length] == 0;
  }
  return value == nil;
}
