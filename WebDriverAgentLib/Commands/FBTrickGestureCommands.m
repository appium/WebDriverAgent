/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBTrickGestureCommands.h"

#import <UIKit/UIKit.h>

#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIApplication.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"

@implementation FBTrickGestureCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[[FBRoute POST:@"/wda/perform_trick_gestures"] withoutSession] respondWithTarget:self action:@selector(handlePerformTrickGestures:)],
  ];
}

#pragma mark - Commands

+ (nullable NSString *)errorDescriptionForWaypoint:(id)waypoint
                                      waypointIndex:(NSUInteger)waypointIndex
                                       gestureIndex:(NSUInteger)gestureIndex
                                  isFirstWaypoint:(BOOL)isFirstWaypoint
{
  if (![waypoint isKindOfClass:NSDictionary.class]) {
    return [NSString stringWithFormat:@"Gesture %lu waypoint %lu must be an object",
            (unsigned long)gestureIndex,
            (unsigned long)waypointIndex];
  }

  NSDictionary *waypointDictionary = (NSDictionary *)waypoint;
  if (nil == waypointDictionary[@"x"] || nil == waypointDictionary[@"y"]) {
    return [NSString stringWithFormat:@"Gesture %lu waypoint %lu must include 'x' and 'y'",
            (unsigned long)gestureIndex,
            (unsigned long)waypointIndex];
  }

  if (!isFirstWaypoint && nil == waypointDictionary[@"duration_ms"]) {
    return [NSString stringWithFormat:@"Gesture %lu waypoint %lu must include 'duration_ms'",
            (unsigned long)gestureIndex,
            (unsigned long)waypointIndex];
  }

  return nil;
}

+ (id<FBResponsePayload>)handlePerformTrickGestures:(FBRouteRequest *)request
{
  id gestures = request.arguments[@"gestures"];
  if (![gestures isKindOfClass:NSArray.class] || [gestures count] == 0) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'gestures' must be a non-empty array"
                                                                        traceback:nil]);
  }

  double delayS = 0;
  id delayMs = request.arguments[@"delay_ms"];
  if (nil != delayMs && ![delayMs isKindOfClass:NSNull.class]) {
    delayS = [delayMs doubleValue] / 1000.0;
  }

  XCSynthesizedEventRecord *eventRecord = [[XCSynthesizedEventRecord alloc]
                                           initWithName:@"TrickGesture"
                                           interfaceOrientation:UIInterfaceOrientationPortrait];

  // All gestures share ONE XCPointerEventPath so they execute as a single
  // sequential finger contact. After each liftUp, a hover moveToPoint
  // repositions without generating a UITouch event, then pressDownAtOffset
  // starts the next contact.
  XCPointerEventPath *path = nil;
  double tCursor = 0.0;

  for (NSUInteger gestureIndex = 0; gestureIndex < [gestures count]; gestureIndex++) {
    id gesture = gestures[gestureIndex];
    if (![gesture isKindOfClass:NSDictionary.class]) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
        [NSString stringWithFormat:@"Gesture %lu must be an object", (unsigned long)gestureIndex]
        traceback:nil]);
    }

    id waypoints = ((NSDictionary *)gesture)[@"waypoints"];
    if (![waypoints isKindOfClass:NSArray.class] || [waypoints count] < 2) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
        [NSString stringWithFormat:@"Gesture %lu must have at least 2 waypoints", (unsigned long)gestureIndex]
        traceback:nil]);
    }

    NSString *validationError = [self errorDescriptionForWaypoint:waypoints[0]
                                                     waypointIndex:0
                                                      gestureIndex:gestureIndex
                                                 isFirstWaypoint:YES];
    if (nil != validationError) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:validationError
                                                                          traceback:nil]);
    }

    NSDictionary *originDict = (NSDictionary *)waypoints[0];
    CGPoint origin = CGPointMake([originDict[@"x"] doubleValue], [originDict[@"y"] doubleValue]);

    if (gestureIndex == 0) {
      // First gesture: create the single path. initForTouchAtPoint:offset:
      // implicitly presses down at offset=0 — no separate pressDownAtOffset needed.
      path = [[XCPointerEventPath alloc] initForTouchAtPoint:origin offset:0.0];
    } else {
      // Subsequent gestures: hover-move to new start position then press.
      // The move after liftUp is a hover (finger lifted), invisible to UITouch handlers.
      [path moveToPoint:origin atOffset:tCursor];
      [path pressDownAtOffset:tCursor];
    }

    for (NSUInteger waypointIndex = 1; waypointIndex < [waypoints count]; waypointIndex++) {
      validationError = [self errorDescriptionForWaypoint:waypoints[waypointIndex]
                                            waypointIndex:waypointIndex
                                             gestureIndex:gestureIndex
                                        isFirstWaypoint:NO];
      if (nil != validationError) {
        return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:validationError
                                                                            traceback:nil]);
      }

      NSDictionary *waypoint = (NSDictionary *)waypoints[waypointIndex];
      tCursor += [waypoint[@"duration_ms"] doubleValue] / 1000.0;
      [path moveToPoint:CGPointMake([waypoint[@"x"] doubleValue], [waypoint[@"y"] doubleValue])
               atOffset:tCursor];
    }

    [path liftUpAtOffset:tCursor];

    if (gestureIndex < [gestures count] - 1) {
      tCursor += delayS;
      if (tCursor < 0) {
        return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
          [NSString stringWithFormat:@"delay_ms=%.0f causes gesture %lu to start before t=0",
           delayS * 1000.0, (unsigned long)(gestureIndex + 1)]
          traceback:nil]);
      }
    }
  }

  [eventRecord addPointerEventPath:path];

  NSError *error;
  if (![FBXCTestDaemonsProxy synthesizeEventWithRecord:eventRecord error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

@end
