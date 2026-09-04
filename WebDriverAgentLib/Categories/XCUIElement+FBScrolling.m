/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
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
#import "XCUIElement+FBResolve.h"
#import "XCUIElement+FBUID.h"
#import "XCUIApplication.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBVisibleFrame.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCTestPrivateSymbols.h"

const CGFloat FBFuzzyPointThreshold = 20.f; //Smallest determined value that is not interpreted as touch
const CGFloat FBScrollToVisibleNormalizedDistance = .5f;
const CGFloat FBTouchEventDelay = 0.5f;
const CGFloat FBTouchVelocity = 300; // pixels per sec
const CGFloat FBScrollTouchProportion = 0.75f;

#if !TARGET_OS_TV

@interface FBXCElementSnapshotWrapper (FBScrolling)

- (BOOL)fb_scrollUpByNormalizedDistance:(CGFloat)distance anchorElement:(XCUIElement *)anchorElement;
- (BOOL)fb_scrollDownByNormalizedDistance:(CGFloat)distance anchorElement:(XCUIElement *)anchorElement;
- (BOOL)fb_scrollLeftByNormalizedDistance:(CGFloat)distance anchorElement:(XCUIElement *)anchorElement;
- (BOOL)fb_scrollRightByNormalizedDistance:(CGFloat)distance anchorElement:(XCUIElement *)anchorElement;
- (BOOL)fb_scrollByNormalizedVector:(CGVector)normalizedScrollVector anchorElement:(XCUIElement *)anchorElement;
- (BOOL)fb_scrollByVector:(CGVector)vector anchorElement:(XCUIElement *)anchorElement error:(NSError **)error;

@end

/**
 Resolves a live element for the given snapshot, so gesture coordinates can be anchored
 to it (its frame gets rescaled by XCTest for compatibility-mode windows; a raw
 XCUIApplication anchor never does - see appium/appium#16185). Returns nil, rather than
 falling back to the application, if the snapshot can no longer be located: anchoring to
 the application would silently reproduce the very bug this is fixing.
 */
static XCUIElement *FBLiveElementForSnapshot(id<FBXCElementSnapshot> snapshot, XCUIApplication *application)
{
  NSString *uid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:snapshot];
  if (nil == uid) {
    return nil;
  }
  XCUIElement *result;
  @autoreleasepool {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", FBStringify(FBXCElementSnapshotWrapper, fb_uid), uid];
    result = [[application.fb_query descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
  }
  result.fb_isResolvedNatively = @NO;
  return result;
}

@implementation XCUIElement (FBScrolling)

- (BOOL)fb_nativeScrollToVisibleWithError:(NSError **)error
{
  [self scrollToVisible];
  if (self.wdVisible) {
    return YES;
  }
  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"Failed to scroll element '%@' into view", self.description]
          buildError:error];
}

- (void)fb_scrollUpByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = [self fb_customSnapshot];
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollUpByNormalizedDistance:distance
                                                                         anchorElement:self];
}

- (void)fb_scrollDownByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = [self fb_customSnapshot];
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollDownByNormalizedDistance:distance
                                                                           anchorElement:self];
}

- (void)fb_scrollLeftByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = [self fb_customSnapshot];
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollLeftByNormalizedDistance:distance
                                                                           anchorElement:self];
}

- (void)fb_scrollRightByNormalizedDistance:(CGFloat)distance
{
  id<FBXCElementSnapshot> snapshot = [self fb_customSnapshot];
  [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_scrollRightByNormalizedDistance:distance
                                                                            anchorElement:self];
}

- (BOOL)fb_scrollToVisibleWithError:(NSError **)error
{
  return [self fb_scrollToVisibleWithNormalizedScrollDistance:FBScrollToVisibleNormalizedDistance error:error];
}

- (BOOL)fb_scrollToVisibleWithNormalizedScrollDistance:(CGFloat)normalizedScrollDistance
                                                 error:(NSError **)error
{
  return [self fb_scrollToVisibleWithNormalizedScrollDistance:normalizedScrollDistance
                                              scrollDirection:FBXCUIElementScrollDirectionUnknown
                                                        error:error];
}

- (BOOL)fb_scrollToVisibleWithNormalizedScrollDistance:(CGFloat)normalizedScrollDistance
                                       scrollDirection:(FBXCUIElementScrollDirection)scrollDirection
                                                 error:(NSError **)error
{
  FBXCElementSnapshotWrapper *prescrollSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:[self fb_customSnapshot]];

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
        if (visibleCellSnapshots.count > 1) {
          return YES;
        }
      }
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

  // The scroll view's own identity is stable across scroll steps, so it only needs
  // to be resolved to a live element once, up front; its frame does not, since it can
  // change across scroll steps (rotation, keyboard, dynamic layout).
  XCUIElement *scrollViewElement = FBLiveElementForSnapshot(scrollView, self.application);
  if (nil == scrollViewElement) {
    return
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to resolve a live element for the scrollable parent of '%@'", self.description]
     buildError:error];
  }

  const NSUInteger maxScrollCount = 25;
  NSUInteger scrollCount = 0;
  FBXCElementSnapshotWrapper *scrollViewWrapped;
  // Scrolling till cell is visible and get current value of frames
  while (![self fb_isEquivalentElementSnapshotVisible:prescrollSnapshot] && scrollCount < maxScrollCount) {
    BOOL didScroll;
    @autoreleasepool {
      // Re-snapshotting the scroll view every step keeps its frame from drifting too far
      // out of sync with the live anchor element's frame used to resolve touch points.
      scrollViewWrapped = [FBXCElementSnapshotWrapper ensureWrapped:[scrollViewElement fb_customSnapshot]];
      if (targetCellIndex < visibleCellIndex) {
        didScroll = scrollDirection == FBXCUIElementScrollDirectionVertical ?
          [scrollViewWrapped fb_scrollUpByNormalizedDistance:normalizedScrollDistance
                                                anchorElement:scrollViewElement] :
          [scrollViewWrapped fb_scrollLeftByNormalizedDistance:normalizedScrollDistance
                                                  anchorElement:scrollViewElement];
      }
      else {
        didScroll = scrollDirection == FBXCUIElementScrollDirectionVertical ?
          [scrollViewWrapped fb_scrollDownByNormalizedDistance:normalizedScrollDistance
                                                  anchorElement:scrollViewElement] :
          [scrollViewWrapped fb_scrollRightByNormalizedDistance:normalizedScrollDistance
                                                   anchorElement:scrollViewElement];
      }
      scrollCount++;
      // Wait for scroll animation
      [self fb_waitUntilStableWithTimeout:FBConfiguration.sharedInstance.animationCoolOffTimeout];
    }
    // The `error` out-param must not be written from inside the autorelease pool above.
    if (!didScroll) {
      return
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to scroll '%@': its frame is empty", self.description]
       buildError:error];
    }
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
  FBXCElementSnapshotWrapper *targetCellSnapshotWrapped = [FBXCElementSnapshotWrapper ensureWrapped:[self fb_customSnapshot]];
  targetCellSnapshot = [targetCellSnapshotWrapped fb_parentCellSnapshot];
  CGRect visibleFrame = [FBXCElementSnapshotWrapper ensureWrapped:targetCellSnapshot].fb_visibleFrame;

  CGVector scrollVector = CGVectorMake(visibleFrame.size.width - targetCellSnapshot.frame.size.width,
                                       visibleFrame.size.height - targetCellSnapshot.frame.size.height
                                       );
  scrollViewWrapped = [FBXCElementSnapshotWrapper ensureWrapped:[scrollViewElement fb_customSnapshot]];
  return [scrollViewWrapped fb_scrollByVector:scrollVector
                                anchorElement:scrollViewElement
                                        error:error];
}

- (BOOL)fb_isEquivalentElementSnapshotVisible:(id<FBXCElementSnapshot>)snapshot
{
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  
  if (wrappedSnapshot.isWDVisible) {
    return YES;
  }

  id<FBXCElementSnapshot> appSnapshot = [self.application fb_standardSnapshot];
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

- (BOOL)fb_scrollUpByNormalizedDistance:(CGFloat)distance
                           anchorElement:(XCUIElement *)anchorElement
{
  return [self fb_scrollByNormalizedVector:CGVectorMake(0.0, distance) anchorElement:anchorElement];
}

- (BOOL)fb_scrollDownByNormalizedDistance:(CGFloat)distance
                             anchorElement:(XCUIElement *)anchorElement
{
  return [self fb_scrollByNormalizedVector:CGVectorMake(0.0, -distance) anchorElement:anchorElement];
}

- (BOOL)fb_scrollLeftByNormalizedDistance:(CGFloat)distance
                             anchorElement:(XCUIElement *)anchorElement
{
  return [self fb_scrollByNormalizedVector:CGVectorMake(distance, 0.0) anchorElement:anchorElement];
}

- (BOOL)fb_scrollRightByNormalizedDistance:(CGFloat)distance
                              anchorElement:(XCUIElement *)anchorElement
{
  return [self fb_scrollByNormalizedVector:CGVectorMake(-distance, 0.0) anchorElement:anchorElement];
}

- (BOOL)fb_scrollByNormalizedVector:(CGVector)normalizedScrollVector
                       anchorElement:(XCUIElement *)anchorElement
{
  CGVector scrollVector = CGVectorMake(CGRectGetWidth(self.scrollingFrame) * normalizedScrollVector.dx,
                                       CGRectGetHeight(self.scrollingFrame) * normalizedScrollVector.dy
                                       );
  return [self fb_scrollByVector:scrollVector anchorElement:anchorElement error:nil];
}

- (BOOL)fb_scrollByVector:(CGVector)vector
             anchorElement:(XCUIElement *)anchorElement
                     error:(NSError **)error
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
    if (![self fb_scrollAncestorScrollViewByVectorWithinScrollViewFrame:scrollVector anchorElement:anchorElement error:error]){
      return NO;
    }
  }
  return YES;
}

// Normalized (0.0-1.0) touch-down offset within the scrolling frame, for the given
// scroll vector's direction.
- (CGVector)fb_normalizedHitPointOffsetForScrollingVector:(CGVector)scrollingVector
{
  CGFloat x = scrollingVector.dx < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion);
  CGFloat y = scrollingVector.dy < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion);
  return CGVectorMake(x, y);
}

- (BOOL)fb_scrollAncestorScrollViewByVectorWithinScrollViewFrame:(CGVector)vector
                                                     anchorElement:(XCUIElement *)anchorElement
                                                             error:(NSError **)error
{
  CGRect scrollingFrame = self.scrollingFrame;
  CGRect anchorFrame = anchorElement.frame;
  if (CGRectIsEmpty(scrollingFrame) || CGRectIsEmpty(anchorFrame)) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Cannot compute a scroll gesture for '%@': its frame is empty", self.fb_description]
            buildError:error];
  }

  // Compute the touch-down/up points within the (possibly clipped) scrolling frame as
  // before, then express them as fractions of the anchor element's own frame instead of
  // raw points, which XCTest never rescales for compatibility-mode windows
  // (appium/appium#16185). When scrollingFrame == anchorFrame this resolves to the exact
  // same absolute point as before; it only differs once XCTest itself rescales anchorFrame.
  CGVector proportion = [self fb_normalizedHitPointOffsetForScrollingVector:vector];
  CGPoint startPoint = CGPointMake((CGFloat)floor(scrollingFrame.origin.x + scrollingFrame.size.width * proportion.dx),
                                   (CGFloat)floor(scrollingFrame.origin.y + scrollingFrame.size.height * proportion.dy));
  CGPoint endPoint = CGPointMake((CGFloat)floor(startPoint.x + vector.dx), (CGFloat)floor(startPoint.y + vector.dy));
  CGVector startOffset = CGVectorMake((startPoint.x - anchorFrame.origin.x) / anchorFrame.size.width,
                                      (startPoint.y - anchorFrame.origin.y) / anchorFrame.size.height);
  CGVector endOffset = CGVectorMake((endPoint.x - anchorFrame.origin.x) / anchorFrame.size.width,
                                    (endPoint.y - anchorFrame.origin.y) / anchorFrame.size.height);
  XCUICoordinate *startCoordinate = [anchorElement coordinateWithNormalizedOffset:startOffset];
  XCUICoordinate *endCoordinate = [anchorElement coordinateWithNormalizedOffset:endOffset];

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
