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
#import "FBSession.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBTouchAction.h"

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
  // Validation failures are client errors (invalid argument); only a dispatch failure
  // is a server/runtime error (unknown error).
  XCSynthesizedEventRecord *eventRecord = [app fb_mobilerunEventRecordFromActions:(NSArray *)items error:&error];
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
