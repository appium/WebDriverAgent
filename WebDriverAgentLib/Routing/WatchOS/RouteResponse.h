/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Minimal, watchOS-only stand-in for Vendor/RoutingHTTPServer/RouteResponse.h, reproducing just
// what FBRoute.m/FBResponseJSONPayload.m call on it. See FBWatchHTTPServer.h.

@import Foundation;
#import <WebDriverAgentLib/FBHTTPStatusCodes.h>

NS_ASSUME_NONNULL_BEGIN

@interface RouteResponse : NSObject

@property (nonatomic) HTTPStatusCode statusCode;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, readonly, nullable) NSData *responseData;

- (void)setHeader:(NSString *)field value:(NSString *)value;
- (void)respondWithString:(NSString *)string;
- (void)respondWithString:(NSString *)string encoding:(NSStringEncoding)encoding;
- (void)respondWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
