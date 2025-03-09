/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCElementSnapshotDouble.h"

#import "FBXCAccessibilityElement.h"
#import "FBXCElementSnapshot.h"
#import "XCUIHitPointResult.h"

@implementation XCElementSnapshotDouble

- (id)init
{
  self = [super init];
  self->_value = @"magicValue";
  self->_label = @"testLabel";
  return self;
}

- (NSString *)identifier
{
  return @"testName";
}

- (CGRect)frame
{
  return CGRectZero;
}

- (NSString *)title
{
  return @"testTitle";
}

- (XCUIElementType)elementType
{
  return XCUIElementTypeOther;
}

- (BOOL)isEnabled
{
  return YES;
}

- (XCUIUserInterfaceSizeClass)horizontalSizeClass
{
  return XCUIUserInterfaceSizeClassUnspecified;
}

- (XCUIUserInterfaceSizeClass)verticalSizeClass
{
  return XCUIUserInterfaceSizeClassUnspecified;
}

- (NSString *)placeholderValue
{
  return @"testPlaceholderValue";
}

- (BOOL)isSelected
{
  return YES;
}

- (BOOL)hasFocus
{
  return YES;
}

- (NSDictionary *)additionalAttributes
{
  return @{};
}

- (id<FBXCAccessibilityElement>)accessibilityElement
{
  return nil;
}

- (id<FBXCElementSnapshot>)parent
{
  return nil;
}

- (XCUIHitPointResult *)hitPoint:(NSError **)error
{
  return [[XCUIHitPointResult alloc] initWithHitPoint:CGPointZero hittable:YES];
}

- (NSArray *)children
{
  return @[];
}

- (NSArray *)_allDescendants
{
  return @[];
}

- (CGRect)visibleFrame
{
  return CGRectZero;
}

@end
