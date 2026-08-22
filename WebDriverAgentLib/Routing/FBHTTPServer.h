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
// No range requests or request pipelining - just request line + headers + Content-Length body,
// and ":param" path matching. Any Transfer-Encoding is rejected outright (501) rather than
// silently mishandled, since no decoder is implemented.

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
 captured into the request's `params`). Equivalent to -handleMethod:withPath:standalone:block:
 with standalone:NO.
 */
- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
               block:(void (^)(RouteRequest *request, RouteResponse *response))block;

/**
 Registers a route handler that, when `standalone` is YES, bypasses -routeQueue entirely so a
 handler stuck on that queue can never block it. Concurrent requests to the same method+path are
 coalesced into a single in-flight execution, whose response is delivered to all of them; anything
 else runs on its own queue, so distinct standalone endpoints always execute in parallel with each
 other and with whatever is stuck on -routeQueue.
 */
- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
          standalone:(BOOL)standalone
               block:(void (^)(RouteRequest *request, RouteResponse *response))block;

/**
 Convenience for -handleMethod:@"GET" withPath:path block:block.
 */
- (void)get:(NSString *)path withBlock:(void (^)(RouteRequest *request, RouteResponse *response))block;

/**
 Immediately sends `response` to every non-standalone request currently pending for the given
 "sessionID" path param - whether still queued on -routeQueue or already executing - instead of
 leaving their HTTP clients waiting on a session that no longer exists. A request that has already
 started executing keeps running to completion in the background regardless (GCD gives no way to
 abort a block once it starts), but its eventual result is discarded rather than ever reaching a
 client. `response` is written as-is to every pending client, so the caller is expected to supply
 a fully-populated, protocol-correct error response (e.g. a W3C-shaped JSON body).
 */
- (void)abandonPendingRequestsForSessionID:(NSString *)sessionID withResponse:(RouteResponse *)response;

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
