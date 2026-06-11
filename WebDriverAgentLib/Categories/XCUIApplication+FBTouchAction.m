/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import "XCUIApplication+FBTouchAction.h"

#import "FBBaseActionsSynthesizer.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBRunLoopSpinner.h"
#import "FBW3CActionsSynthesizer.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCEventGenerator.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBUtilities.h"

#if !TARGET_OS_TV

@implementation XCUIApplication (FBTouchAction)

+ (BOOL)handleEventSynthesWithError:(NSError *)error
{
  if ([error.localizedDescription containsString:@"not visible"]) {
    [[NSException exceptionWithName:FBElementNotVisibleException
                             reason:error.localizedDescription
                           userInfo:error.userInfo] raise];
  }
  return NO;
}

- (BOOL)fb_performActionsWithSynthesizerType:(Class)synthesizerType
                                     actions:(NSArray *)actions
                                elementCache:(FBElementCache *)elementCache
                                       error:(NSError **)error
{
  FBBaseActionsSynthesizer *synthesizer = [[synthesizerType alloc] initWithActions:actions
                                                                    forApplication:self
                                                                      elementCache:elementCache
                                                                             error:error];
  if (nil == synthesizer) {
    return NO;
  }
  XCSynthesizedEventRecord *eventRecord = [synthesizer synthesizeWithError:error];
  if (nil == eventRecord) {
    return [self.class handleEventSynthesWithError:*error];
  }
  return [self fb_synthesizeEvent:eventRecord error:error];
}

- (BOOL)fb_performW3CActions:(NSArray *)actions
                elementCache:(FBElementCache *)elementCache
                       error:(NSError **)error
{
  if (![self fb_performActionsWithSynthesizerType:FBW3CActionsSynthesizer.class
                                          actions:actions
                                     elementCache:elementCache
                                            error:error]) {
    return NO;
  }
  [self fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  return YES;
}

- (BOOL)fb_mobilerunPoint:(CGPoint *)outPoint fromItem:(NSDictionary *)item scale:(CGFloat)scale error:(NSError **)error
{
  id x = item[@"x"];
  id y = item[@"y"];
  if (![x isKindOfClass:NSNumber.class] || ![y isKindOfClass:NSNumber.class]) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Action item requires numeric 'x' and 'y': %@", item]
            buildError:error];
  }
  // mobilerun coordinates are logical points multiplied by the request's scale (matching
  // /mobilerun/state bounds for the same scale; the default native scale matches the
  // screencapture stream); XCPointerEventPath expects logical points, so divide it back out.
  CGFloat s = scale > 0 ? scale : 1.0;
  *outPoint = CGPointMake([x doubleValue] / s, [y doubleValue] / s);
  return YES;
}

- (XCSynthesizedEventRecord *)fb_mobilerunEventRecordFromActions:(NSArray *)items scale:(CGFloat)scale error:(NSError **)error
{
  if (![items isKindOfClass:NSArray.class] || 0 == items.count) {
    [[[FBErrorBuilder builder]
      withDescription:@"Mobilerun actions must be a non-empty array"]
     buildError:error];
    return nil;
  }

  // One touch path per pointerId, each with its own running offset (ms).
  NSMutableDictionary<NSNumber *, XCPointerEventPath *> *paths = [NSMutableDictionary dictionary];
  NSMutableDictionary<NSNumber *, NSNumber *> *offsets = [NSMutableDictionary dictionary];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];
  // Pointers whose path was just created by a leading pointerMove. That move's
  // initForTouchAtPoint already presses the touch down, so a pointerDown immediately after it is
  // redundant — the W3C synthesizer no-ops that first down and we match it.
  NSMutableSet<NSNumber *> *leadingMovePointers = [NSMutableSet set];

  for (id rawItem in items) {
    if (![rawItem isKindOfClass:NSDictionary.class]) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Each action item must be an object: %@", rawItem]
       buildError:error];
      return nil;
    }
    NSDictionary *item = (NSDictionary *)rawItem;

    id type = item[@"type"];
    if (![type isKindOfClass:NSString.class]) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Action item is missing a string 'type': %@", item]
       buildError:error];
      return nil;
    }

    NSNumber *pointerId = [item[@"pointerId"] isKindOfClass:NSNumber.class] ? item[@"pointerId"] : @0;
    double offsetMs = offsets[pointerId] ? offsets[pointerId].doubleValue : 0.0;
    double durationMs = [item[@"duration"] isKindOfClass:NSNumber.class] ? [item[@"duration"] doubleValue] : 0.0;
    XCPointerEventPath *path = paths[pointerId];
    BOOL afterLeadingMove = [leadingMovePointers containsObject:pointerId];

    if ([type isEqualToString:@"pause"]) {
      // No event; only advances this pointer's offset below.
    } else if ([type isEqualToString:@"pointerDown"]) {
      CGPoint point = CGPointZero;
      if (![self fb_mobilerunPoint:&point fromItem:item scale:scale error:error]) {
        return nil;
      }
      if (nil == path) {
        path = [[XCPointerEventPath alloc] initForTouchAtPoint:point offset:FBMillisToSeconds(offsetMs)];
        paths[pointerId] = path;
        [order addObject:pointerId];
      } else if (!afterLeadingMove) {
        [path pressDownAtOffset:FBMillisToSeconds(offsetMs)];
      }
      // else: a leading pointerMove already pressed the touch down; skip the redundant press.
    } else if ([type isEqualToString:@"pointerMove"]) {
      CGPoint point = CGPointZero;
      if (![self fb_mobilerunPoint:&point fromItem:item scale:scale error:error]) {
        return nil;
      }
      if (nil == path) {
        path = [[XCPointerEventPath alloc] initForTouchAtPoint:point offset:FBMillisToSeconds(offsetMs + durationMs)];
        paths[pointerId] = path;
        [order addObject:pointerId];
        [leadingMovePointers addObject:pointerId];
      } else {
        [path moveToPoint:point atOffset:FBMillisToSeconds(offsetMs + durationMs)];
      }
    } else if ([type isEqualToString:@"pointerUp"]) {
      if (nil == path) {
        [[[FBErrorBuilder builder]
          withDescriptionFormat:@"'pointerUp' for pointer %@ has no preceding 'pointerDown'", pointerId]
         buildError:error];
        return nil;
      }
      [path liftUpAtOffset:FBMillisToSeconds(offsetMs)];
    } else {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Unsupported action type '%@'. Supported: pointerDown, pointerMove, pointerUp, pause", type]
       buildError:error];
      return nil;
    }

    // The leading-move window only covers the single item immediately following the move.
    if (afterLeadingMove) {
      [leadingMovePointers removeObject:pointerId];
    }

    offsets[pointerId] = @(offsetMs + durationMs);
  }

  if (0 == paths.count) {
    [[[FBErrorBuilder builder]
      withDescription:@"No pointer events were produced by the actions"]
     buildError:error];
    return nil;
  }

  XCSynthesizedEventRecord *eventRecord =
    [[XCSynthesizedEventRecord alloc] initWithName:@"Mobilerun Action"
                              interfaceOrientation:self.interfaceOrientation];
  for (NSNumber *pointerId in order) {
    [eventRecord addPointerEventPath:paths[pointerId]];
  }
  return eventRecord;
}

- (BOOL)fb_performMobilerunActions:(NSArray *)items scale:(CGFloat)scale error:(NSError **)error
{
  XCSynthesizedEventRecord *eventRecord = [self fb_mobilerunEventRecordFromActions:items scale:scale error:error];
  if (nil == eventRecord) {
    return NO;
  }
  return [self fb_synthesizeEvent:eventRecord error:error];
}

- (void)fb_mobilerunPressAndDragFromPoint:(CGPoint)from
                                  toPoint:(CGPoint)to
                            pressDuration:(double)pressDuration
                                 velocity:(CGFloat)velocity
                             holdDuration:(double)holdDuration
{
  XCUICoordinate *base = [self coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
  XCUICoordinate *start = [base coordinateWithOffset:CGVectorMake(from.x, from.y)];
  XCUICoordinate *end = [base coordinateWithOffset:CGVectorMake(to.x, to.y)];
  // The XCUICoordinate gesture engine waits for app quiescence around the gesture (the swizzle
  // in XCUIApplicationProcess+FBQuiescence honours this flag); suppressing it for the duration
  // of the call is what makes this path faster than /wda/pressAndDragWithVelocity.
  BOOL previousQuiescence = self.fb_shouldWaitForQuiescence;
  self.fb_shouldWaitForQuiescence = NO;
  @try {
    [start pressForDuration:pressDuration
       thenDragToCoordinate:end
               withVelocity:velocity
        thenHoldForDuration:holdDuration];
  } @finally {
    self.fb_shouldWaitForQuiescence = previousQuiescence;
  }
}

- (BOOL)fb_synthesizeEvent:(XCSynthesizedEventRecord *)event error:(NSError *__autoreleasing*)error
{
  return [FBXCTestDaemonsProxy synthesizeEventWithRecord:event error:error];
}

@end
#endif
