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

@interface FBVideoCommands : NSObject <FBCommandHandler>

+ (id<FBResponsePayload>)handleStartVideoRecording:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleStopVideoRecording:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetVideoRecording:(FBRouteRequest *)request;

@end

NS_ASSUME_NONNULL_END
