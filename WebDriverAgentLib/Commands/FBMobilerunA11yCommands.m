/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMobilerunA11yCommands.h"

#import "FBCommandStatus.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"

// Parses the optional 'scale' query parameter shared by the mobilerun endpoints. Response/request
// coordinates are logical points multiplied by this scale; it defaults to the native screen scale
// (device pixels), and 'scale=1' yields plain points. Returns NO when the parameter is present but
// is not a positive number. Keep in sync with the copy in FBMobilerunActionsCommands.m.
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

@implementation FBMobilerunA11yCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/mobilerun/state"] respondWithTarget:self action:@selector(handleGetState:)],
    [[FBRoute GET:@"/mobilerun/state"].withoutSession respondWithTarget:self action:@selector(handleGetState:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetState:(FBRouteRequest *)request
{
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  CGFloat scale;
  if (!FBMobilerunScaleFromRequest(request, &scale)) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'scale' must be a positive number"
                                                                       traceback:nil]);
  }
  return FBResponseWithObject([app fb_mobilerunA11yStateWithScale:scale]);
}

@end
