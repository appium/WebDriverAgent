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

@interface FBCustomCommands : NSObject <FBCommandHandler>

// Session & application lifecycle
+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleDeactivateAppCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleTimeouts:(FBRouteRequest *)request;

// Keyboard & input
+ (id<FBResponsePayload>)handleDismissKeyboardCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePingCommand:(FBRouteRequest *)request;

// Screen & device state
+ (id<FBResponsePayload>)handleGetScreen:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleLock:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleIsLocked:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleActiveAppInfo:(FBRouteRequest *)request;

#if !TARGET_OS_TV
// Clipboard & battery (iOS only)
+ (id<FBResponsePayload>)handleSetPasteboard:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetPasteboard:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetBatteryInfo:(FBRouteRequest *)request;
#endif

// Hardware buttons & Siri
+ (id<FBResponsePayload>)handlePressButtonCommand:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleActivateSiri:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePeformIOHIDEvent:(FBRouteRequest *)request;

// App launching & permissions
+ (id<FBResponsePayload>)handleLaunchUnattachedApp:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleResetAppAuth:(FBRouteRequest *)request;

// Device information & appearance
+ (id<FBResponsePayload>)handleGetDeviceInfo:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSetDeviceAppearance:(FBRouteRequest *)request;

// Location
+ (id<FBResponsePayload>)handleGetLocation:(FBRouteRequest *)request;
#if !TARGET_OS_TV
+ (id<FBResponsePayload>)handleGetSimulatedLocation:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSetSimulatedLocation:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleClearSimulatedLocation:(FBRouteRequest *)request;
#if __clang_major__ >= 15
+ (id<FBResponsePayload>)handleKeyboardInput:(FBRouteRequest *)request;
#endif
#endif

// Notifications & audits
+ (id<FBResponsePayload>)handleExpectNotification:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePerformAccessibilityAudit:(FBRouteRequest *)request;

@end

NS_ASSUME_NONNULL_END
