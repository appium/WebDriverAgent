/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <WebDriverAgentLib/FBCommandHandler.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBSessionCommands : NSObject <FBCommandHandler>

// Session management
+ (id<FBResponsePayload>)handleCreateSession:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetActiveSession:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleDeleteSession:(FBRouteRequest *)request;

// URL handling
+ (id<FBResponsePayload>)handleOpenURL:(FBRouteRequest *)request;

// App management
+ (id<FBResponsePayload>)handleSessionAppLaunch:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSessionAppActivate:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSessionAppTerminate:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSessionAppState:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetActiveAppsList:(FBRouteRequest *)request;

// Status and health
+ (id<FBResponsePayload>)handleGetStatus:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetHealthCheck:(FBRouteRequest *)request;

// Settings
+ (id<FBResponsePayload>)handleGetSettings:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSetSettings:(FBRouteRequest *)request;

// Utility methods
+ (NSDictionary *)sessionInformation;
+ (NSDictionary *)currentCapabilities;

// Device helper
+ (NSString *)deviceNameByUserInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom;

// Deep link opening helper
+ (nullable id<FBResponsePayload>)openDeepLink:(NSString *)initialUrl
                               withApplication:(nullable NSString *)bundleID
                                       timeout:(nullable NSNumber *)timeout;
@end

NS_ASSUME_NONNULL_END
