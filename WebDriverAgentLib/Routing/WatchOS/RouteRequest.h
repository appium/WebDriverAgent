/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Minimal, watchOS-only stand-in for Vendor/RoutingHTTPServer/RouteRequest.h, which is not
// available on watchOS because RoutingHTTPServer/CocoaHTTPServer/CocoaAsyncSocket cannot be
// built there (see FBWatchHTTPServer.h). Exposes just the surface FBWebServer's route blocks
// and FBRoute.decorateRequest: read.

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface RouteRequest : NSObject

@property (nonatomic, copy, readonly) NSURL *url;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *params;
@property (nonatomic, copy, readonly) NSData *body;

- (instancetype)initWithURL:(NSURL *)url
                      params:(NSDictionary<NSString *, NSString *> *)params
                        body:(NSData *)body;

@end

NS_ASSUME_NONNULL_END
