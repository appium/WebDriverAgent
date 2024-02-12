/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTouchActionCommands.h"

#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication+FBTouchAction.h"

@implementation FBTouchActionCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/actions"] respondWithTarget:self action:@selector(handlePerformW3CTouchActions:)],
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

@end
