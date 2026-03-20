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

@interface FBFindElementCommands : NSObject <FBCommandHandler>

+ (id<FBResponsePayload>)handleFindElement:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleFindElements:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleFindVisibleCells:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleFindSubElement:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleFindSubElements:(FBRouteRequest *)request;

#if TARGET_OS_TV
+ (id<FBResponsePayload>)handleGetFocusedElement:(FBRouteRequest *)request;
#else
+ (id<FBResponsePayload>)handleGetActiveElement:(FBRouteRequest *)request;
#endif

@end

NS_ASSUME_NONNULL_END
