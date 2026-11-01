/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBTouchActionCommands.h"

#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication+FBTouchAction.h"
// FBBaseActionsSynthesizer.h transitively imports XCPointerEventPath.h and
// XCSynthesizedEventRecord.h — these are the private XCTest APIs used by
// the /wda/absolute-actions handler below.
#import "FBBaseActionsSynthesizer.h"
#import "FBXCTestDaemonsProxy.h"

@implementation FBTouchActionCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/actions"] respondWithTarget:self action:@selector(handlePerformW3CTouchActions:)],
    // /wda/absolute-actions: synthesise W3C pointer actions at absolute screen
    // coordinates using XCSynthesizedEventRecord, without resolving the active
    // application. Works with or without a session.
    [[FBRoute POST:@"/wda/absolute-actions"].withoutSession respondWithTarget:self action:@selector(handleAbsoluteTouchActions:)],
    [[FBRoute POST:@"/wda/absolute-actions"] respondWithTarget:self action:@selector(handleAbsoluteTouchActions:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handlePerformW3CTouchActions:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication;
  NSArray *actions = (NSArray *)request.arguments[@"actions"];
  NSError *error;
  if (![application fb_performW3CActions:actions elementCache:request.session.elementCache error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

// Parse a single W3C pointer source from the actions array and replay it as
// an XCSynthesizedEventRecord.  Only the "pointer"/"touch" source type is
// supported; keyboard/wheel sources are silently ignored.
//
// Unlike the session-bound /actions handler, this does not resolve the active
// XCUIApplication, so it works without a live session and does not depend on
// the application's accessibility state.
+ (id<FBResponsePayload>)handleAbsoluteTouchActions:(FBRouteRequest *)request
{
  NSArray *sources = request.arguments[@"actions"];
  if (![sources isKindOfClass:[NSArray class]] || sources.count == 0) {
    return FBResponseWithOK();
  }

  XCSynthesizedEventRecord *record =
    [[XCSynthesizedEventRecord alloc] initWithName:@"WDAAbsoluteTouch"
                                 interfaceOrientation:0];

  for (NSDictionary *source in sources) {
    NSString *sourceType = source[@"type"];
    if (![sourceType isKindOfClass:[NSString class]] ||
        ![@"pointer" isEqualToString:sourceType]) continue;
    NSDictionary *params = source[@"parameters"];
    if (params) {
      NSString *ptrType = params[@"pointerType"];
      if ([ptrType isKindOfClass:[NSString class]] &&
          ![@"touch" isEqualToString:ptrType]) continue;
    }

    NSArray *actionItems = source[@"actions"];
    if (![actionItems isKindOfClass:[NSArray class]]) continue;

    // Walk the action items to find the first pointerMove (the starting
    // point), then build an XCPointerEventPath from the sequence.
    BOOL foundStart = NO;
    NSTimeInterval cursor = 0.0;   // seconds elapsed in the gesture

    XCPointerEventPath *path = nil;

    for (NSDictionary *item in actionItems) {
      NSString *type = item[@"type"];
      if (![type isKindOfClass:[NSString class]]) continue;
      NSNumber *durationMs = item[@"duration"];
      NSTimeInterval durationSec = durationMs ? [durationMs doubleValue] / 1000.0 : 0.0;

      if ([type isEqualToString:@"pointerMove"]) {
        NSNumber *px = item[@"x"];
        NSNumber *py = item[@"y"];
        if (![px isKindOfClass:[NSNumber class]] ||
            ![py isKindOfClass:[NSNumber class]]) continue;
        CGPoint pt = CGPointMake([px doubleValue], [py doubleValue]);
        if (!foundStart) {
          foundStart = YES;
          path = [[XCPointerEventPath alloc] initForTouchAtPoint:pt offset:cursor];
        } else if (path) {
          cursor += durationSec;
          [path moveToPoint:pt atOffset:cursor];
        }
      } else if ([type isEqualToString:@"pointerDown"]) {
        if (path) [path pressDownAtOffset:cursor];
      } else if ([type isEqualToString:@"pointerUp"]) {
        if (path) [path liftUpAtOffset:cursor];
      } else if ([type isEqualToString:@"pause"]) {
        cursor += durationSec;
      }
    }

    if (path) {
      [record addPointerEventPath:path];
    }
  }

  NSError *error;
  if (![FBXCTestDaemonsProxy synthesizeEventWithRecord:record error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

@end
