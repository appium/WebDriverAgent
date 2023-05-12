/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBScrolling.h"

#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBXCodeCompatibility.h"
#import "FBXCElementSnapshotWrapper.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIApplication.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

const CGFloat FBFuzzyPointThreshold = 20.f; //Smallest determined value that is not interpreted as touch
const CGFloat FBScrollToVisibleNormalizedDistance = .5f;
const CGFloat FBTouchEventDelay = 0.5f;
const CGFloat FBTouchVelocity = 300; // pixels per sec
const CGFloat FBScrollTouchProportion = 0.75f;

#if !TARGET_OS_TV

@interface FBXCElementSnapshotWrapper (FBScrolling)

- (void)fb_scrollUpByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application;
- (void)fb_scrollDownByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application;
- (void)fb_scrollLeftByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application;
- (void)fb_scrollRightByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application;
- (BOOL)fb_scrollByNormalizedVector:(CGVector)normalizedScrollVector inApplication:(XCUIApplication *)application;
- (BOOL)fb_scrollByVector:(CGVector)vector inApplication:(XCUIApplication *)application error:(NSError **)error;

@end

@implementation XCUIElement (FBScrolling)

- (BOOL)fb_nativeScrollToVisibleWithError:(NSError **)error
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  return nil != [self _hitPointByAttemptingToScrollToVisibleSnapshot:snapshot
                                                               error:error];
}

- (void)fb_scrollUpByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollUpByNormalizedDistance:distance
                                                                         inApplication:self.application];
}

- (void)fb_scrollDownByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollDownByNormalizedDistance:distance
                                                                           inApplication:self.application];
}

- (void)fb_scrollLeftByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollLeftByNormalizedDistance:distance
                                                                           inApplication:self.application];
}

- (void)fb_scrollRightByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollRightByNormalizedDistance:distance
                                                                            inApplication:self.application];
}

- (BOOL)fb_scrollToVisibleWithError:(NSError **)error
{
  return [self fb_scrollToVisibleWithNormalizedScrollDistance:FBScrollToVisibleNormalizedDistance error:error];
}

- (BOOL)fb_scrollToVisibleWithNormalizedScrollDistance:(CGFloat)normalizedScrollDistance error:(NSError **)error
{
  return [self fb_scrollToVisibleWithNormalizedScrollDistance:normalizedScrollDistance
                                              scrollDirection:FBXCUIElementScrollDirectionUnknown
                                                        error:error];
}

- (BOOL)fb_scrollToVisibleWithNormalizedScrollDistance:(CGFloat)normalizedScrollDistance
                                       scrollDirection:(FBXCUIElementScrollDirection)scrollDirection
                                                 error:(NSError **)error
{
  FBXCElementSnapshotWrapper *prescrollSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:[self fb_takeSnapshot]];
  if (prescrollSnapshot.isWDVisible) {
    return YES;
  }

  static dispatch_once_t onceToken;
  static NSArray *acceptedParents;
  dispatch_once(&onceToken, ^{
    acceptedParents = @[
      @(XCUIElementTypeScrollView),
      @(XCUIElementTypeCollectionView),
      @(XCUIElementTypeTable),
      @(XCUIElementTypeWebView),
    ];
  });

  __block NSArray<id<FBXCElementSnapshot>> *cellSnapshots;
  __block NSMutableArray<id<FBXCElementSnapshot>> *visibleCellSnapshots = [NSMutableArray new];
  id<FBXCElementSnapshot> scrollView = [prescrollSnapshot fb_parentMatchingOneOfTypes:acceptedParents
      filter:^(id<FBXCElementSnapshot> snapshot) {
    FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
    
    if (![wrappedSnapshot isWDVisible]) {
      return NO;
    }

    cellSnapshots = [wrappedSnapshot fb_descendantsCellSnapshots];
    
    for (id<FBXCElementSnapshot> cellSnapshot in cellSnapshots) {
      FBXCElementSnapshotWrapper *wrappedCellSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:cellSnapshot];
      if (wrappedCellSnapshot.wdVisible) {
        [visibleCellSnapshots addObject:cellSnapshot];
      }
    }

    if (visibleCellSnapshots.count > 1) {
      return YES;
    }
    return NO;
  }];

  if (scrollView == nil) {
    return
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to find scrollable visible parent with 2 visible children"]
     buildError:error];
  }

  id<FBXCElementSnapshot> targetCellSnapshot = [prescrollSnapshot fb_parentCellSnapshot];
  id<FBXCElementSnapshot> lastSnapshot = visibleCellSnapshots.lastObject;
  // Can't just do indexOfObject, because targetCellSnapshot may represent the same object represented by a member of cellSnapshots, yet be a different object
  // than that member. This reflects the fact that targetCellSnapshot came out of self.fb_parentCellSnapshot, not out of cellSnapshots directly.
  // If the result is NSNotFound, we'll just proceed by scrolling downward/rightward, since NSNotFound will always be larger than the current index.
  NSUInteger targetCellIndex = [cellSnapshots indexOfObjectPassingTest:^BOOL(id<FBXCElementSnapshot> _Nonnull obj,
                                                                             NSUInteger idx, BOOL *_Nonnull stop) {
    return [obj _matchesElement:targetCellSnapshot];
  }];
  NSUInteger visibleCellIndex = [cellSnapshots indexOfObject:lastSnapshot];

  if (scrollDirection == FBXCUIElementScrollDirectionUnknown) {
    // Try to determine the scroll direction by determining the vector between the first and last visible cells
    id<FBXCElementSnapshot> firstVisibleCell = visibleCellSnapshots.firstObject;
    id<FBXCElementSnapshot> lastVisibleCell = visibleCellSnapshots.lastObject;
    CGVector cellGrowthVector = CGVectorMake(firstVisibleCell.frame.origin.x - lastVisibleCell.frame.origin.x,
                                             firstVisibleCell.frame.origin.y - lastVisibleCell.frame.origin.y
                                             );
    if (ABS(cellGrowthVector.dy) > ABS(cellGrowthVector.dx)) {
      scrollDirection = FBXCUIElementScrollDirectionVertical;
    } else {
      scrollDirection = FBXCUIElementScrollDirectionHorizontal;
    }
  }

  const NSUInteger maxScrollCount = 25;
  NSUInteger scrollCount = 0;
  FBXCElementSnapshotWrapper *scrollViewWrapped = [FBXCElementSnapshotWrapper ensureWrapped:scrollView];
  // Scrolling till cell is visible and get current value of frames
  while (![self fb_isEquivalentElementSnapshotVisible:prescrollSnapshot] && scrollCount < maxScrollCount) {
    if (targetCellIndex < visibleCellIndex) {
      scrollDirection == FBXCUIElementScrollDirectionVertical ?
        [scrollViewWrapped fb_scrollUpByNormalizedDistance:normalizedScrollDistance
                                             inApplication:self.application] :
        [scrollViewWrapped fb_scrollLeftByNormalizedDistance:normalizedScrollDistance
                                               inApplication:self.application];
    }
    else {
      scrollDirection == FBXCUIElementScrollDirectionVertical ?
        [scrollViewWrapped fb_scrollDownByNormalizedDistance:normalizedScrollDistance
                                               inApplication:self.application] :
        [scrollViewWrapped fb_scrollRightByNormalizedDistance:normalizedScrollDistance
                                                inApplication:self.application];
    }
    scrollCount++;
    // Wait for scroll animation
    [self fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  }

  if (scrollCount >= maxScrollCount) {
    return
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to perform scroll with visible cell due to max scroll count reached"]
     buildError:error];
  }

  // Cell is now visible, but it might be only partialy visible, scrolling till whole frame is visible.
  // Sometimes, attempting to grab the parent snapshot of the target cell after scrolling is complete causes a stale element reference exception.
  // Trying fb_cachedSnapshot first
  FBXCElementSnapshotWrapper *targetCellSnapshotWrapped = [FBXCElementSnapshotWrapper ensureWrapped:([self fb_cachedSnapshot] ?: [self fb_takeSnapshot])];
  targetCellSnapshot = [targetCellSnapshotWrapped fb_parentCellSnapshot];
  CGRect visibleFrame = [FBXCElementSnapshotWrapper ensureWrapped:targetCellSnapshot].fb_visibleFrameWithFallback;
  
  CGVector scrollVector = CGVectorMake(visibleFrame.size.width - targetCellSnapshot.frame.size.width,
                                       visibleFrame.size.height - targetCellSnapshot.frame.size.height
                                       );
  return [scrollViewWrapped fb_scrollByVector:scrollVector
                                inApplication:self.application
                                        error:error];
}

- (BOOL)fb_isEquivalentElementSnapshotVisible:(id<FBXCElementSnapshot>)snapshot
{
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  
  if (wrappedSnapshot.isWDVisible) {
    return YES;
  }

  id<FBXCElementSnapshot> appSnapshot = [self.application fb_takeSnapshot];
  for (id<FBXCElementSnapshot> elementSnapshot in appSnapshot._allDescendants.copy) {
    FBXCElementSnapshotWrapper *wrappedElementSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:elementSnapshot];
    // We are comparing pre-scroll snapshot so frames are irrelevant.
    if ([wrappedSnapshot fb_framelessFuzzyMatchesElement:elementSnapshot]
        && wrappedElementSnapshot.isWDVisible) {
      return YES;
    }
  }
  return NO;
}

@end


@implementation FBXCElementSnapshotWrapper (FBScrolling)

- (CGRect)scrollingFrame
{
  return self.visibleFrame;
}

- (void)fb_scrollUpByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application
{
  [self fb_scrollByNormalizedVector:CGVectorMake(0.0, distance) inApplication:application];
}

- (void)fb_scrollDownByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application
{
  [self fb_scrollByNormalizedVector:CGVectorMake(0.0, -distance) inApplication:application];
}

- (void)fb_scrollLeftByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application
{
  [self fb_scrollByNormalizedVector:CGVectorMake(distance, 0.0) inApplication:application];
}

- (void)fb_scrollRightByNormalizedDistance:(CGFloat)distance inApplication:(XCUIApplication *)application
{
  [self fb_scrollByNormalizedVector:CGVectorMake(-distance, 0.0) inApplication:application];
}

- (BOOL)fb_scrollByNormalizedVector:(CGVector)normalizedScrollVector inApplication:(XCUIApplication *)application
{
  CGVector scrollVector = CGVectorMake(CGRectGetWidth(self.scrollingFrame) * normalizedScrollVector.dx,
                                       CGRectGetHeight(self.scrollingFrame) * normalizedScrollVector.dy
                                       );
  return [self fb_scrollByVector:scrollVector inApplication:application error:nil];
}

- (BOOL)fb_scrollByVector:(CGVector)vector inApplication:(XCUIApplication *)application error:(NSError **)error
{
  CGVector scrollBoundingVector = CGVectorMake(
                                               CGRectGetWidth(self.scrollingFrame) * FBScrollTouchProportion,
                                               CGRectGetHeight(self.scrollingFrame) * FBScrollTouchProportion
                                               );
  scrollBoundingVector.dx = (CGFloat)floor(copysign(scrollBoundingVector.dx, vector.dx));
  scrollBoundingVector.dy = (CGFloat)floor(copysign(scrollBoundingVector.dy, vector.dy));

  NSInteger preciseScrollAttemptsCount = 20;
  CGVector CGZeroVector = CGVectorMake(0, 0);
  BOOL shouldFinishScrolling = NO;
  while (!shouldFinishScrolling) {
    CGVector scrollVector = CGVectorMake(fabs(vector.dx) > fabs(scrollBoundingVector.dx) ? scrollBoundingVector.dx : vector.dx,
                                         fabs(vector.dy) > fabs(scrollBoundingVector.dy) ? scrollBoundingVector.dy : vector.dy);
    vector = CGVectorMake(vector.dx - scrollVector.dx, vector.dy - scrollVector.dy);
    shouldFinishScrolling = FBVectorFuzzyEqualToVector(vector, CGZeroVector, 1) || --preciseScrollAttemptsCount <= 0;
    if (![self fb_scrollAncestorScrollViewByVectorWithinScrollViewFrame:scrollVector inApplication:application error:error]){
      return NO;
    }
  }
  return YES;
}

- (CGVector)fb_hitPointOffsetForScrollingVector:(CGVector)scrollingVector
{
  CGFloat x = CGRectGetMinX(self.scrollingFrame) + CGRectGetWidth(self.scrollingFrame) * (scrollingVector.dx < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion));
  CGFloat y = CGRectGetMinY(self.scrollingFrame) + CGRectGetHeight(self.scrollingFrame) * (scrollingVector.dy < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion));
  return CGVectorMake((CGFloat)floor(x), (CGFloat)floor(y));
}

- (BOOL)fb_scrollAncestorScrollViewByVectorWithinScrollViewFrame:(CGVector)vector inApplication:(XCUIApplication *)application error:(NSError **)error
{
  CGVector hitpointOffset = [self fb_hitPointOffsetForScrollingVector:vector];

  XCUICoordinate *appCoordinate = [[XCUICoordinate alloc] initWithElement:application normalizedOffset:CGVectorMake(0.0, 0.0)];
  XCUICoordinate *startCoordinate = [[XCUICoordinate alloc] initWithCoordinate:appCoordinate pointsOffset:hitpointOffset];
  XCUICoordinate *endCoordinate = [[XCUICoordinate alloc] initWithCoordinate:startCoordinate pointsOffset:vector];

  if (FBPointFuzzyEqualToPoint(startCoordinate.screenPoint, endCoordinate.screenPoint, FBFuzzyPointThreshold)) {
    return YES;
  }

  [startCoordinate pressForDuration:FBTouchEventDelay
               thenDragToCoordinate:endCoordinate
                       withVelocity:FBTouchVelocity
                thenHoldForDuration:FBTouchEventDelay];
  return YES;
}

@end

#endif
