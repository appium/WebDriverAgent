/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <WebDriverAgentLib/FBCommandHandler.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBAlertViewCommands : NSObject <FBCommandHandler>

+ (id<FBResponsePayload>)handleAlertGetTextCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleAlertSetTextCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleAlertAcceptCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleAlertDismissCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetAlertButtonsCommand:(FBRouteRequest *)request;

@end

NS_ASSUME_NONNULL_END
