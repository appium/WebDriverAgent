/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// A minimal HTTP/1.1 server on top of FBTCPSocket (Network.framework-backed on every platform,
// since watchOS forbids BSD sockets outright - see FBTCPSocket.h/.m).
//
// No chunked encoding, range requests, or pipelining - just request line + headers +
// Content-Length body, and ":param" path matching.

@import Foundation;

#import "RouteRequest.h"
#import "RouteResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBHTTPServer : NSObject

/*! The port the server is (or will be) listening on */
@property (nonatomic) uint16_t port;

/*! Whether the server is currently listening for connections */
@property (nonatomic, readonly) BOOL isRunning;

/**
 Sets the dispatch queue on which route blocks are invoked. Pass NULL to invoke them
 synchronously on the socket's own queue.
 */
- (void)setRouteQueue:(nullable dispatch_queue_t)queue;

/**
 Sets a header which is added to every response, unless overridden by the route itself.
 */
- (void)setDefaultHeader:(NSString *)field value:(NSString *)value;

/**
 Sets the local IP address to bind the listener to. Must be called before -start:. Pass nil (the
 default) to listen on all interfaces.
 */
- (void)setInterface:(nullable NSString *)interface;

/**
 Registers a route handler for the given HTTP method and path pattern (":param" segments are
 captured into the request's `params`).
 */
- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
               block:(void (^)(RouteRequest *request, RouteResponse *response))block;

/**
 Convenience for -handleMethod:@"GET" withPath:path block:block.
 */
- (void)get:(NSString *)path withBlock:(void (^)(RouteRequest *request, RouteResponse *response))block;

/**
 Starts listening on `port`.
 */
- (BOOL)start:(NSError **)error;

/**
 Stops listening and disconnects all clients.
 */
- (void)stop:(BOOL)immediately;

@end

NS_ASSUME_NONNULL_END
