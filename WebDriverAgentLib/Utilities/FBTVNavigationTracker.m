/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBTVNavigationTracker.h"
#import "FBTVNavigationTracker-Private.h"

#import "FBMathUtils.h"
#import "FBXCElementSnapshotWrapper.h"
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
    _targetCenter = FBRectGetCenter(targetElement.wdFrame);
    _navigationItems = [NSMutableDictionary dictionary];
  }
  return self;
}

- (FBTVFocusState)pollFocusState:(FBTVDirection *)direction
{
  *direction = FBTVDirectionNone;

  // `hasFocus`/`exists` are cheap, single-element live checks - each round
  // trip only has to serialize the state of one already-known element, not
  // an unbounded subtree, so there's no snapshot-walk win to be had here.
  if (self.targetElement.hasFocus) {
    return FBTVFocusStateFocused;
  }
  if (!self.targetElement.exists) {
    return FBTVFocusStateGone;
  }

  // Likewise, a `hasFocus == true` predicate query only has to serialize its
  // (typically 0-1) matches back over the round trip, unlike a whole-app
  // snapshot walk, whose cost scales with total app size/depth.
  XCUIElement *focusedElement = (XCUIElement *)XCUIApplication.fb_activeApplication.fb_focusedElement;
  if (nil == focusedElement) {
    // Nothing is focused yet (e.g. right after the app became active) - let
    // the caller retry on the next iteration.
    return FBTVFocusStatePending;
  }

  // The snapshot was already taken as a side effect of resolving the query
  // above, so grab it for free instead of paying for a new round trip.
  id<FBXCElementSnapshot> focusedSnapshot = focusedElement.lastSnapshot
    ?: focusedElement.fb_cachedSnapshot
    ?: [focusedElement fb_customSnapshot];
  *direction = [self directionTowardsTargetFromFocusedElementSnapshot:focusedSnapshot];

  return FBTVFocusStatePending;
}

- (FBTVDirection)directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot
{
  FBXCElementSnapshotWrapper *focused = [FBXCElementSnapshotWrapper ensureWrapped:focusedSnapshot];
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
  return [self directionWithItem:item
                            delta:delta
                positiveDirection:FBTVDirectionRight
                negativeDirection:FBTVDirectionLeft];
}

- (FBTVDirection)verticalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta
{
  return [self directionWithItem:item
                            delta:delta
                positiveDirection:FBTVDirectionDown
                negativeDirection:FBTVDirectionUp];
}

- (FBTVDirection)directionWithItem:(FBTVNavigationItem *)item
                              delta:(CGFloat)delta
                  positiveDirection:(FBTVDirection)positiveDirection
                  negativeDirection:(FBTVDirection)negativeDirection
{
  // CGFloat is double in 64bit. tvOS is only for arm64
  NSNumber *positiveDirectionNumber = [NSNumber numberWithInteger:positiveDirection];
  NSNumber *negativeDirectionNumber = [NSNumber numberWithInteger:negativeDirection];
  if (delta > DBL_EPSILON && ![item.directions containsObject:positiveDirectionNumber]) {
    [item.directions addObject:positiveDirectionNumber];
    return positiveDirection;
  }
  if (delta < -DBL_EPSILON && ![item.directions containsObject:negativeDirectionNumber]) {
    [item.directions addObject:negativeDirectionNumber];
    return negativeDirection;
  }
  return FBTVDirectionNone;
}

@end

#endif
