/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMobilerunA11yCommands.h"

#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"

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
  CGFloat scale = (CGFloat)[FBScreen scale];
  return FBResponseWithObject([app fb_mobilerunA11yStateWithScale:scale]);
}

@end
