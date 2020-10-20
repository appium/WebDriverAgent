/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCElementSnapshot+FBHelpers.h"

#import "FBFindElementCommands.h"
#import "FBRunLoopSpinner.h"
#import "FBLogger.h"
#import "FBXCAXClientProxy.h"
#import "XCTestDriver.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIElement.h"
#import "XCUIElement+FBWebDriverAttributes.h"

inline static BOOL isSnapshotTypeAmongstGivenTypes(XCElementSnapshot* snapshot, NSArray<NSNumber *> *types);

@implementation XCElementSnapshot (FBHelpers)

- (NSString *)fb_description
{
  NSString *result = [NSString stringWithFormat:@"%@", self.wdType];
  if (nil != self.wdName) {
    result = [NSString stringWithFormat:@"%@ (%@)", result, self.wdName];
  }
  return result;
}

- (NSArray<XCElementSnapshot *> *)fb_descendantsMatchingType:(XCUIElementType)type
{
  return [self descendantsByFilteringWithBlock:^BOOL(XCElementSnapshot *snapshot) {
    return snapshot.elementType == type;
  }];
}

- (XCElementSnapshot *)fb_parentMatchingType:(XCUIElementType)type
{
  NSArray *acceptedParents = @[@(type)];
  return [self fb_parentMatchingOneOfTypes:acceptedParents];
}

- (XCElementSnapshot *)fb_parentMatchingOneOfTypes:(NSArray<NSNumber *> *)types
{
  return [self fb_parentMatchingOneOfTypes:types filter:^(XCElementSnapshot *snapshot) {
    return YES;
  }];
}

- (XCElementSnapshot *)fb_parentMatchingOneOfTypes:(NSArray<NSNumber *> *)types filter:(BOOL(^)(XCElementSnapshot *snapshot))filter
{
  XCElementSnapshot *snapshot = self.parent;
  while (snapshot && !(isSnapshotTypeAmongstGivenTypes(snapshot, types) && filter(snapshot))) {
    snapshot = snapshot.parent;
  }
  return snapshot;
}

- (id)fb_attributeValue:(NSString *)attribute
{
  NSDictionary *result = [FBXCAXClientProxy.sharedClient attributesForElement:[self accessibilityElement]
                                                                   attributes:@[attribute]];
  return result[attribute];
}

inline static BOOL valuesAreEqual(id value1, id value2);

inline static BOOL isNilOrEmpty(id value);

- (BOOL)fb_framelessFuzzyMatchesElement:(XCElementSnapshot *)snapshot
{
    // Pure payload-based comparison sometimes yield false negatives, therefore relying on it only if all of the identifying properties are blank
  if (isNilOrEmpty(self.identifier) && isNilOrEmpty(self.title) && isNilOrEmpty(self.label) &&
      isNilOrEmpty(self.value) && isNilOrEmpty(self.placeholderValue)) {
    return [self.wdUID isEqualToString:(snapshot.wdUID ?: @"")];
  }
  
  return self.elementType == snapshot.elementType &&
    valuesAreEqual(self.identifier, snapshot.identifier) &&
    valuesAreEqual(self.title, snapshot.title) &&
    valuesAreEqual(self.label, snapshot.label) &&
    valuesAreEqual(self.value, snapshot.value) &&
    valuesAreEqual(self.placeholderValue, snapshot.placeholderValue);
}

- (NSArray<XCElementSnapshot *> *)fb_descendantsCellSnapshots
{
  NSArray<XCElementSnapshot *> *cellSnapshots = [self fb_descendantsMatchingType:XCUIElementTypeCell];
    
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

- (NSArray<XCElementSnapshot *> *)fb_ancestors
{
  NSMutableArray<XCElementSnapshot *> *ancestors = [NSMutableArray array];
  XCElementSnapshot *parent = self.parent;
  while (parent) {
    [ancestors addObject:parent];
    parent = parent.parent;
  }
  return ancestors.copy;
}

- (XCElementSnapshot *)fb_parentCellSnapshot
{
    XCElementSnapshot *targetCellSnapshot = self;
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
@end

inline static BOOL isSnapshotTypeAmongstGivenTypes(XCElementSnapshot* snapshot, NSArray<NSNumber *> *types)
{
  for (NSUInteger i = 0; i < types.count; i++) {
   if([@(snapshot.elementType) isEqual: types[i]] || [types[i] isEqual: @(XCUIElementTypeAny)]){
       return YES;
   }
  }
  return NO;
}

inline static BOOL valuesAreEqual(id value1, id value2)
{
  return value1 == value2 || [value1 isEqual:value2];
}

inline static BOOL isNilOrEmpty(id value)
{
  if ([value isKindOfClass:NSString.class]) {
    return [(NSString*)value length] == 0;
  }
  return value == nil;
}
