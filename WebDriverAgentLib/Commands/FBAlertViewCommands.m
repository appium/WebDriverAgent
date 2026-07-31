/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAlertViewCommands.h"

#import "FBAlert.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication+FBHelpers.h"

@implementation FBAlertViewCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/alert/text"] respondWithTarget:self action:@selector(handleAlertGetTextCommand:)],
    [[FBRoute GET:@"/alert/text"].withoutSession respondWithTarget:self action:@selector(handleAlertGetTextCommand:)],
    [[FBRoute POST:@"/alert/text"] respondWithTarget:self action:@selector(handleAlertSetTextCommand:)],
    [[FBRoute POST:@"/alert/accept"] respondWithTarget:self action:@selector(handleAlertAcceptCommand:)],
    [[FBRoute POST:@"/alert/accept"].withoutSession respondWithTarget:self action:@selector(handleAlertAcceptCommand:)],
    [[FBRoute POST:@"/alert/dismiss"] respondWithTarget:self action:@selector(handleAlertDismissCommand:)],
    [[FBRoute POST:@"/alert/dismiss"].withoutSession respondWithTarget:self action:@selector(handleAlertDismissCommand:)],
    [[FBRoute GET:@"/wda/alert/buttons"] respondWithTarget:self action:@selector(handleGetAlertButtonsCommand:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleAlertGetTextCommand:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSString *alertText = [FBAlert alertWithApplication:application].text;
  if (!alertText) {
    return FBResponseWithStatus([FBCommandStatus noAlertOpenErrorWithMessage:nil
                                                                   traceback:nil]);
  }
  return FBResponseWithObject(alertText);
}

+ (id<FBResponsePayload>)handleAlertSetTextCommand:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  id value = request.arguments[@"value"];
  if (!value) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Missing 'value' parameter" traceback:nil]);
  }
  FBAlert *alert = [FBAlert alertWithApplication:session.activeApplication];
  NSString *textToType = value;
  if ([value isKindOfClass:[NSArray class]]) {
    textToType = [value componentsJoinedByString:@""];
  }
  [alert typeText:textToType];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleAlertAcceptCommand:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSString *name = request.arguments[@"name"];
  FBAlert *alert = [FBAlert alertWithApplication:application];

  if (name) {
    [alert clickAlertButton:name];
  } else {
    [alert accept];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleAlertDismissCommand:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSString *name = request.arguments[@"name"];
  FBAlert *alert = [FBAlert alertWithApplication:application];

  if (name) {
    [alert clickAlertButton:name];
  } else {
    [alert dismiss];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetAlertButtonsCommand:(FBRouteRequest *)request {
  FBSession *session = request.session;
  FBAlert *alert = [FBAlert alertWithApplication:session.activeApplication];

  NSArray *labels = alert.buttonLabels;
  if (!labels) {
    return FBResponseWithStatus([FBCommandStatus noAlertOpenErrorWithMessage:nil
                                                                   traceback:nil]);
  }
  return FBResponseWithObject(labels);
}
@end
