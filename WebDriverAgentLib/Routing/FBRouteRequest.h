/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@class FBSession;

NS_ASSUME_NONNULL_BEGIN

/**
 Class that represents WebDriverAgent command request
 */
@interface FBRouteRequest : NSObject

/*! Request's URL */
@property (nonatomic, strong, readonly) NSURL *URL;

/*! Parameters sent with that request */
@property (nonatomic, copy, readonly) NSDictionary *parameters;

/*! Arguments sent with that request */
@property (nonatomic, copy, readonly) NSDictionary *arguments;

/*! Session associated with that request */
@property (nonatomic, strong, readonly) FBSession *session;

/**
 Convenience constructor for request
 */
+ (instancetype)routeRequestWithURL:(NSURL *)URL parameters:(NSDictionary *)parameters arguments:(NSDictionary *)arguments;

/**
 Convenience constructor for request that also sets the associated session.

 @param URL Request URL
 @param parameters Path/query parameters
 @param arguments JSON body arguments
 @param session The FBSession instance to associate with the request. May be nil.
 */
+ (instancetype)routeRequestWithURL:(NSURL *)URL
                          parameters:(NSDictionary *)parameters
                            arguments:(NSDictionary *)arguments
                              session:(nullable FBSession *)session;

@end

NS_ASSUME_NONNULL_END
