/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import "XCUIApplication+FBTouchAction.h"

#import <dlfcn.h>

#import "FBBaseActionsSynthesizer.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBMathUtils.h"
#import "FBRunLoopSpinner.h"
#import "FBW3CActionsSynthesizer.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCUIElement+FBUtilities.h"

#if !TARGET_OS_TV && !TARGET_OS_WATCH

/**
 Maps a drag XCUIGestureVelocity to the speed XCTest drags at, or returns 0 if the velocity is
 invalid. XCTest calls the result "pixels per second", but divides the distance between the two
 screen points (which are in points) by it. Prefers XCTest's own (exported, but undeclared) mapping
 function, so any future change to its presets is picked up; falls back to the values it returns now.
 */
static CGFloat FBPointsPerSecondForDragVelocity(XCUIGestureVelocity velocity)
{
  BOOL isPreset = FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocityDefault, 0)
    || FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocitySlow, 0)
    || FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocityFast, 0);
  if (!isPreset && !(isfinite(velocity) && velocity > 0)) {
    // XCTest itself raises for such values ("Velocity must be a value greater than 0")
    return 0;
  }
  static double (*xctestMapping)(double) = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    xctestMapping = (double (*)(double))dlsym(RTLD_DEFAULT, "XCUIPixelsPerSecondForDragGestureVelocity");
  });
  if (NULL != xctestMapping) {
    return (CGFloat)xctestMapping(velocity);
  }
  if (FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocitySlow, 0)) {
    return 250;
  }
  if (FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocityFast, 0)) {
    return 750;
  }
  return FBFloatFuzzyEqualToFloat(velocity, XCUIGestureVelocityDefault, 0) ? 500 : velocity;
}

static BOOL FBIsFinitePoint(CGPoint point)
{
  return isfinite(point.x) && isfinite(point.y);
}

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
  [self fb_waitUntilStableWithTimeout:FBConfiguration.sharedInstance.animationCoolOffTimeout];
  return YES;
}

- (BOOL)fb_pressAtCoordinate:(XCUICoordinate *)startCoordinate
                 forDuration:(NSTimeInterval)pressDuration
        thenDragToCoordinate:(XCUICoordinate *)endCoordinate
                withVelocity:(XCUIGestureVelocity)velocity
         thenHoldForDuration:(NSTimeInterval)holdDuration
                       error:(NSError **)error
{
  CGFloat pointsPerSecond = FBPointsPerSecondForDragVelocity(velocity);
  if (pointsPerSecond <= 0) {
    NSString *reason = [NSString stringWithFormat:@"%@ is an invalid drag velocity. It must be greater than 0", @(velocity)];
    @throw [NSException exceptionWithName:FBInvalidArgumentException reason:reason userInfo:nil];
  }
  if (!(isfinite(pressDuration) && pressDuration >= 0) || !(isfinite(holdDuration) && holdDuration >= 0)) {
    NSString *reason = [NSString stringWithFormat:@"Drag press and hold durations must be non-negative numbers of seconds. Got %@ and %@", @(pressDuration), @(holdDuration)];
    @throw [NSException exceptionWithName:FBInvalidArgumentException reason:reason userInfo:nil];
  }

  // Resolved once, here, so the points validated below are exactly the ones sent. XCTest's own
  // drag re-resolves them inside its event dispatch instead, after re-snapshotting the application.
  CGPoint startPoint = startCoordinate.screenPoint;
  CGPoint endPoint = endCoordinate.screenPoint;
  if (!FBIsFinitePoint(startPoint) || !FBIsFinitePoint(endPoint)) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Cannot resolve the on-screen position of the drag gesture (from %@ to %@). "
             "This usually means '%@' did not deliver a valid accessibility snapshot, e.g. because it is busy "
             "or still transitioning after an application switch. Make sure it is idle and retry",
             NSStringFromCGPoint(startPoint), NSStringFromCGPoint(endPoint), self.bundleID]
            buildError:error];
  }

  // Mirrors XCTest's own press-hold-drag event builder
  XCPointerEventPath *path = [[XCPointerEventPath alloc] initForTouchAtPoint:startPoint offset:0];
  if (pressDuration > 0) {
    [path moveToPoint:startPoint atOffset:pressDuration];
  }
  CGFloat distance = (CGFloat)hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y);
  NSTimeInterval dragEndOffset = pressDuration + distance / pointsPerSecond;
  [path moveToPoint:endPoint atOffset:dragEndOffset];
  [path liftUpAtOffset:dragEndOffset + holdDuration];

  XCSynthesizedEventRecord *event = [[XCSynthesizedEventRecord alloc] initWithName:@"Press, drag and hold"
                                                              interfaceOrientation:self.interfaceOrientation];
  [event addPointerEventPath:path];
  if (![self fb_synthesizeEvent:event error:error]) {
    return NO;
  }
  [self fb_waitUntilStableWithTimeout:FBConfiguration.sharedInstance.animationCoolOffTimeout];
  return YES;
}

- (BOOL)fb_synthesizeEvent:(XCSynthesizedEventRecord *)event error:(NSError *__autoreleasing*)error
{
  return [FBXCTestDaemonsProxy synthesizeEventWithRecord:event error:error];
}

@end
#endif
