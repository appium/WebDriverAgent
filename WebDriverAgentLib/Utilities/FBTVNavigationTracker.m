/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTVNavigationTracker.h"

#import "FBApplication.h"
#import "FBMathUtils.h"
#import "XCUIApplication+FBFocused.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

#if TARGET_OS_TV

@interface FBTVNavigationItem : NSObject
@property (nonatomic, readonly) NSUInteger uid;
@property (nonatomic, readonly) NSMutableSet<NSNumber *>* directions;

+ (instancetype)itemWithUid:(NSUInteger) uid;
@end

@implementation FBTVNavigationItem

+ (instancetype)itemWithUid:(NSUInteger) uid
{
  return [[FBTVNavigationItem alloc] initWithUid:uid];
}

- (instancetype)initWithUid:(NSUInteger) uid
{
  self = [super init];
  if(self) {
    _uid = uid;
    _directions = [NSMutableSet set];
  }
  return self;
}

@end

@interface FBTVNavigationTracker ()
@property (nonatomic, strong) id<FBElement> targetElement;
@property (nonatomic, assign) CGPoint targetCenter;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FBTVNavigationItem* >* navigationItems;
@end

@implementation FBTVNavigationTracker

+ (instancetype)trackerWithTargetElement:(id<FBElement>)targetElement
{
  FBTVNavigationTracker *tracker = [[FBTVNavigationTracker alloc] initWithTargetElement:targetElement];
  tracker.targetElement = targetElement;
  return tracker;
}

- (instancetype)initWithTargetElement:(id<FBElement>)targetElement
{
  self = [super init];
  if(self) {
    _targetElement = targetElement;
    _targetCenter = FBRectGetCenter(targetElement.wdFrame);
    _navigationItems = [NSMutableDictionary dictionary];
  }
  return self;
}

- (FBTVDirection)directionToFocusedElement
{
  id<FBElement> focused = self.focusedElement;
  CGPoint focusedCenter = FBRectGetCenter(focused.wdFrame);
  FBTVNavigationItem *item = [self navigationItemWithElement:focused];
  CGFloat yDelta = self.targetCenter.y - focusedCenter.y;
  CGFloat xDelta = self.targetCenter.x - focusedCenter.x;
  FBTVDirection direction;
  if (fabs(yDelta) > fabs(xDelta)) {
    direction = [self getVerticalDirectionForItem:item withDelta:yDelta];
    if (direction == FBTVDirectionNone) {
      direction = [self getHorizontalDirectionForItem:item withDelta:xDelta];
    }
  } else {
    direction = [self getHorizontalDirectionForItem:item withDelta:xDelta];
    if (direction == FBTVDirectionNone) {
      direction = [self getVerticalDirectionForItem:item withDelta:yDelta];
    }
  }

  return direction;
}

#pragma mark - Utilities
- (id<FBElement>)focusedElement
{
  return [FBApplication fb_activeApplication].fb_focusedElement;
}

- (FBTVNavigationItem*)navigationItemWithElement:(id<FBElement>)element
{
  NSNumber *key = [NSNumber numberWithUnsignedInteger:element.wdUID];
  FBTVNavigationItem* item = [self.navigationItems objectForKey: key];
  if(item) {
    return item;
  }
  item = [FBTVNavigationItem itemWithUid:element.wdUID];
  [self.navigationItems setObject:item forKey:key];
  return item;
}

- (FBTVDirection)getHorizontalDirectionForItem:(FBTVNavigationItem *)item withDelta:(CGFloat)delta
{
  // GCFloat is double in 64bit. tvOS is only for arm64
  if (delta > DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionRight]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionRight]];
    return FBTVDirectionRight;
  }
  if (delta < DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionLeft]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionLeft]];
    return FBTVDirectionLeft;
  }
  return FBTVDirectionNone;
}

- (FBTVDirection)getVerticalDirectionForItem:(FBTVNavigationItem *)item withDelta:(CGFloat)delta
{
  // GCFloat is double in 64bit. tvOS is only for arm64
  if (delta > DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionDown]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionDown]];
    return FBTVDirectionDown;
  }
  if (delta < DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionUp]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionUp]];
    return FBTVDirectionUp;
  }
  return FBTVDirectionNone;
}

@end

#endif
