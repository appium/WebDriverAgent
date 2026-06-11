/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMobilerunActionsCommands.h"

#import "FBCommandStatus.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBTouchAction.h"

// Parses the optional 'scale' query parameter shared by the mobilerun endpoints. Response/request
// coordinates are logical points multiplied by this scale; it defaults to the native screen scale
// (device pixels), and 'scale=1' yields plain points. Returns NO when the parameter is present but
// is not a positive number. Keep in sync with the copy in FBMobilerunA11yCommands.m.
static BOOL FBMobilerunScaleFromRequest(FBRouteRequest *request, CGFloat *scale)
{
  NSString *rawScale = request.parameters[@"scale"];
  if (0 == rawScale.length) {
    *scale = (CGFloat)[FBScreen scale];
    return YES;
  }
  NSScanner *scanner = [NSScanner scannerWithString:rawScale];
  double value = 0;
  if (![scanner scanDouble:&value] || !scanner.isAtEnd || value <= 0) {
    return NO;
  }
  *scale = (CGFloat)value;
  return YES;
}

// Routes are serialized on the main queue and the handler blocks for the gesture's physical
// duration, so an unbounded press/drag/hold would wedge every other endpoint.
static const double kFBMobilerunMaxGestureDurationSec = 60.0;

// Reads a finite numeric field from the body into 'outValue'. Missing optional fields take
// 'fallback'; a missing required field, a non-number, or a non-finite value (e.g. 1e999
// parses to +inf) fails.
static BOOL FBMobilerunNumberFromBody(NSDictionary *body, NSString *key, BOOL required, double fallback, double *outValue)
{
  id raw = body[key];
  if (nil == raw) {
    if (required) {
      return NO;
    }
    *outValue = fallback;
    return YES;
  }
  if (![raw isKindOfClass:NSNumber.class] || !isfinite([raw doubleValue])) {
    return NO;
  }
  *outValue = [raw doubleValue];
  return YES;
}

@implementation FBMobilerunActionsCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    // The XCUIApplication+FBTouchAction category backing these handlers is not compiled for
    // tvOS, so registering the routes there would crash with an unrecognized selector instead
    // of responding 404 like the guarded /wda touch routes.
#if !TARGET_OS_TV
    [[FBRoute POST:@"/mobilerun/actions"] respondWithTarget:self action:@selector(handlePerformActions:)],
    [[FBRoute POST:@"/mobilerun/actions"].withoutSession respondWithTarget:self action:@selector(handlePerformActions:)],
    [[FBRoute POST:@"/mobilerun/pressAndDragWithVelocity"] respondWithTarget:self action:@selector(handlePressAndDragWithVelocity:)],
    [[FBRoute POST:@"/mobilerun/pressAndDragWithVelocity"].withoutSession respondWithTarget:self action:@selector(handlePressAndDragWithVelocity:)],
#endif
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handlePerformActions:(FBRouteRequest *)request
{
  // A top-level JSON array body arrives in request.arguments as an NSArray.
  id items = request.arguments;
  if (![items isKindOfClass:NSArray.class]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request body must be a JSON array of action items"
                                                                       traceback:nil]);
  }
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSError *error;
  // Action x/y are logical points multiplied by the request's scale, so they match what
  // /mobilerun/state returns for the same 'scale' query parameter. Without the parameter both
  // endpoints use the native screen scale (device pixels, matching the screencapture stream).
  CGFloat scale;
  if (!FBMobilerunScaleFromRequest(request, &scale)) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'scale' must be a positive number"
                                                                       traceback:nil]);
  }
  // Validation failures are client errors (invalid argument); only a dispatch failure
  // is a server/runtime error (unknown error).
  XCSynthesizedEventRecord *eventRecord = [app fb_mobilerunEventRecordFromActions:(NSArray *)items scale:scale error:&error];
  if (nil == eventRecord) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  if (![app fb_synthesizeEvent:eventRecord error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePressAndDragWithVelocity:(FBRouteRequest *)request
{
  id body = request.arguments;
  if (![body isKindOfClass:NSDictionary.class]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request body must be a JSON object"
                                                                       traceback:nil]);
  }
  CGFloat scale;
  if (!FBMobilerunScaleFromRequest(request, &scale)) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'scale' must be a positive number"
                                                                       traceback:nil]);
  }
  // Coordinates and velocity share the request's scale, matching /mobilerun/state and
  // /mobilerun/actions; 'scale=1' yields the /wda/pressAndDragWithVelocity units (logical
  // points and points per second). Durations are seconds, like the /wda endpoint.
  double fromX, fromY, toX, toY, pressDuration, velocity, holdDuration;
  NSString *badField = nil;
  if (!FBMobilerunNumberFromBody(body, @"fromX", YES, 0, &fromX)) {
    badField = @"fromX";
  } else if (!FBMobilerunNumberFromBody(body, @"fromY", YES, 0, &fromY)) {
    badField = @"fromY";
  } else if (!FBMobilerunNumberFromBody(body, @"toX", YES, 0, &toX)) {
    badField = @"toX";
  } else if (!FBMobilerunNumberFromBody(body, @"toY", YES, 0, &toY)) {
    badField = @"toY";
  } else if (!FBMobilerunNumberFromBody(body, @"velocity", YES, 0, &velocity)) {
    badField = @"velocity";
  } else if (!FBMobilerunNumberFromBody(body, @"pressDuration", NO, 0, &pressDuration)) {
    badField = @"pressDuration";
  } else if (!FBMobilerunNumberFromBody(body, @"holdDuration", NO, 0, &holdDuration)) {
    badField = @"holdDuration";
  }
  if (nil != badField) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"'%@' must be a finite number", badField]
                                                                       traceback:nil]);
  }
  if (velocity <= 0) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'velocity' must be a positive number"
                                                                       traceback:nil]);
  }
  if (pressDuration < 0 || holdDuration < 0) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'pressDuration' and 'holdDuration' must be non-negative"
                                                                       traceback:nil]);
  }
  // Scale cancels out in distance/velocity, so the estimate is correct in any unit.
  double totalDuration = pressDuration + hypot(toX - fromX, toY - fromY) / velocity + holdDuration;
  if (totalDuration > kFBMobilerunMaxGestureDurationSec) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"The gesture would take %.1fs; the maximum is %.0fs", totalDuration, kFBMobilerunMaxGestureDurationSec]
                                                                       traceback:nil]);
  }
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  [app fb_mobilerunPressAndDragFromPoint:CGPointMake(fromX / scale, fromY / scale)
                                 toPoint:CGPointMake(toX / scale, toY / scale)
                           pressDuration:pressDuration
                                velocity:velocity / scale
                            holdDuration:holdDuration];
  return FBResponseWithOK();
}

@end
