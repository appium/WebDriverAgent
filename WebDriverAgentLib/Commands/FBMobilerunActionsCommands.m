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

@implementation FBMobilerunActionsCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/mobilerun/actions"] respondWithTarget:self action:@selector(handlePerformActions:)],
    [[FBRoute POST:@"/mobilerun/actions"].withoutSession respondWithTarget:self action:@selector(handlePerformActions:)],
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

@end
