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

@interface FBElementCommands : NSObject <FBCommandHandler>

// Element attribute retrieval
+ (id<FBResponsePayload>)handleGetEnabled:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetRect:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetAttribute:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetText:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetDisplayed:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetAccessible:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetIsAccessibilityContainer:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetName:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetSelected:(FBRouteRequest *)request;

// Element interaction
+ (id<FBResponsePayload>)handleSetValue:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleClick:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleClear:(FBRouteRequest *)request;

#if TARGET_OS_TV
// tvOS specific
+ (id<FBResponsePayload>)handleGetFocused:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleFocuse:(FBRouteRequest *)request;
#else
// iOS specific gestures
+ (id<FBResponsePayload>)handleDoubleTap:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleTwoFingerTap:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleTapWithNumberOfTaps:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleTouchAndHold:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePressAndDragWithVelocity:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePressAndDragCoordinateWithVelocity:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleScroll:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleScrollTo:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleDrag:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSwipe:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleTap:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handlePinch:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleRotate:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleForceTouch:(FBRouteRequest *)request;
#endif

// Keyboard input
+ (id<FBResponsePayload>)handleKeys:(FBRouteRequest *)request;

// Window metrics
+ (id<FBResponsePayload>)handleGetWindowSize:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleGetWindowRect:(FBRouteRequest *)request;

// Screenshots
+ (id<FBResponsePayload>)handleElementScreenshot:(FBRouteRequest *)request;

#if !TARGET_OS_TV
// Picker wheel
+ (id<FBResponsePayload>)handleWheelSelect:(FBRouteRequest *)request;
#endif

@end

NS_ASSUME_NONNULL_END
