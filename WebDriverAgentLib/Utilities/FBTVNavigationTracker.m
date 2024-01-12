/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTVNavigationTracker.h"
#import "FBTVNavigationTracker-Private.h"

#import "FBMathUtils.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIApplication+FBHelpers.h"

#if TARGET_OS_TV

@implementation FBTVNavigationItem

+ (instancetype)itemWithUid:(NSString *) uid
{
  return [[FBTVNavigationItem alloc] initWithUid:uid];
}

- (instancetype)initWithUid:(NSString *) uid
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
@property (nonatomic, strong) XCUIElement *targetElement;
@property (nonatomic, assign) CGPoint targetCenter;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FBTVNavigationItem* >* navigationItems;
@end

@implementation FBTVNavigationTracker

+ (instancetype)trackerWithTargetElement:(XCUIElement *)targetElement
{
  FBTVNavigationTracker *tracker = [[FBTVNavigationTracker alloc] initWithTargetElement:targetElement];
  tracker.targetElement = targetElement;
  return tracker;
}

- (instancetype)initWithTargetElement:(XCUIElement *)targetElement
{
  self = [super init];
  if (self) {
    _targetElement = targetElement;
    CGRect frame = targetElement.fb_isResolvedFromCache.boolValue
      ? [FBXCElementSnapshotWrapper ensureWrapped:targetElement.lastSnapshot].wdFrame
      : targetElement.wdFrame;
    _targetCenter = FBRectGetCenter(frame);
    _navigationItems = [NSMutableDictionary dictionary];
  }
  return self;
}

- (FBTVDirection)directionToFocusedElement
{
  XCUIElement *focused = XCUIApplication.fb_activeApplication.fb_focusedElement;

  CGPoint focusedCenter = FBRectGetCenter(focused.wdFrame);
  FBTVNavigationItem *item = [self navigationItemWithElement:focused];
  CGFloat yDelta = self.targetCenter.y - focusedCenter.y;
  CGFloat xDelta = self.targetCenter.x - focusedCenter.x;
  FBTVDirection direction;
  if (fabs(yDelta) > fabs(xDelta)) {
    direction = [self verticalDirectionWithItem:item andDelta:yDelta];
    if (direction == FBTVDirectionNone) {
      direction = [self horizontalDirectionWithItem:item andDelta:xDelta];
    }
  } else {
    direction = [self horizontalDirectionWithItem:item andDelta:xDelta];
    if (direction == FBTVDirectionNone) {
      direction = [self verticalDirectionWithItem:item andDelta:yDelta];
    }
  }

  return direction;
}

#pragma mark - Utilities
- (FBTVNavigationItem*)navigationItemWithElement:(id<FBElement>)element
{
  NSString *uid = element.wdUID;
  if (nil == uid) {
    return nil;
  }

  FBTVNavigationItem* item = [self.navigationItems objectForKey:uid];
  if (nil != item) {
    return item;
  }
  
  item = [FBTVNavigationItem itemWithUid:uid];
  [self.navigationItems setObject:item forKey:uid];
  return item;
}

- (FBTVDirection)horizontalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta
{
  // GCFloat is double in 64bit. tvOS is only for arm64
  if (delta > DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionRight]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionRight]];
    return FBTVDirectionRight;
  }
  if (delta < -DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionLeft]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionLeft]];
    return FBTVDirectionLeft;
  }
  return FBTVDirectionNone;
}

- (FBTVDirection)verticalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta
{
  // GCFloat is double in 64bit. tvOS is only for arm64
  if (delta > DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionDown]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionDown]];
    return FBTVDirectionDown;
  }
  if (delta < -DBL_EPSILON &&
      ![item.directions containsObject: [NSNumber numberWithInteger: FBTVDirectionUp]]) {
    [item.directions addObject: [NSNumber numberWithInteger: FBTVDirectionUp]];
    return FBTVDirectionUp;
  }
  return FBTVDirectionNone;
}

@end

#endif
