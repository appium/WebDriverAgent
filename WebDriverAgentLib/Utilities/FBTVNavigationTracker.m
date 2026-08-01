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
@property (nonatomic, nullable, copy) NSString *targetUid;
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
    // Called once per tracker (not per polling iteration), so the extra
    // round trip here is negligible next to the per-iteration savings below.
    _targetCenter = FBRectGetCenter(targetElement.wdFrame);
    _targetUid = targetElement.wdUID;
    _navigationItems = [NSMutableDictionary dictionary];
  }
  return self;
}

- (FBTVFocusState)pollFocusState:(FBTVDirection *)direction
{
  // One snapshot walk of the whole app answers everything the polling loop
  // needs - whether the target still exists, whether it already has focus,
  // and (if not) where the currently focused element is - instead of the
  // 4 separate live AX round trips (`hasFocus`, `exists`, a focused-element
  // query, plus a snapshot of it) this used to cost per iteration.
  return [self pollFocusStateWithApplicationSnapshot:XCUIApplication.fb_activeApplication.fb_customSnapshot
                                            direction:direction];
}

- (FBTVFocusState)pollFocusStateWithApplicationSnapshot:(id<FBXCElementSnapshot>)appSnapshot
                                                direction:(FBTVDirection *)direction
{
  *direction = FBTVDirectionNone;
  NSString *targetUid = self.targetUid;
  __block id<FBXCElementSnapshot> targetSnapshot = nil;
  __block id<FBXCElementSnapshot> focusedSnapshot = nil;
  [appSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil != targetUid && [[FBXCElementSnapshotWrapper ensureWrapped:descendant].wdUID isEqualToString:targetUid]) {
      targetSnapshot = descendant;
    }
    if (descendant.hasFocus) {
      focusedSnapshot = descendant;
    }
  }];

  if (nil == targetSnapshot) {
    return FBTVFocusStateGone;
  }
  if (targetSnapshot.hasFocus) {
    return FBTVFocusStateFocused;
  }
  if (nil == focusedSnapshot) {
    // Nothing is focused yet (e.g. right after the app became active) - let
    // the caller retry on the next iteration.
    return FBTVFocusStatePending;
  }

  FBXCElementSnapshotWrapper *focused = [FBXCElementSnapshotWrapper ensureWrapped:focusedSnapshot];
  CGPoint focusedCenter = FBRectGetCenter(focused.wdFrame);
  FBTVNavigationItem *item = [self navigationItemWithElement:focused];
  CGFloat yDelta = self.targetCenter.y - focusedCenter.y;
  CGFloat xDelta = self.targetCenter.x - focusedCenter.x;
  if (fabs(yDelta) > fabs(xDelta)) {
    *direction = [self verticalDirectionWithItem:item andDelta:yDelta];
    if (*direction == FBTVDirectionNone) {
      *direction = [self horizontalDirectionWithItem:item andDelta:xDelta];
    }
  } else {
    *direction = [self horizontalDirectionWithItem:item andDelta:xDelta];
    if (*direction == FBTVDirectionNone) {
      *direction = [self verticalDirectionWithItem:item andDelta:yDelta];
    }
  }

  return FBTVFocusStatePending;
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
  // GCFloat is double in 64bit. tvOS is only for arm64
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
