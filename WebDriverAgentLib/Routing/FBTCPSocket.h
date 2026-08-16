/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// TARGET_OS_WATCH must be defined before the #if below runs, or (on some older Xcode/SDK
// toolchains) it silently evaluates as undefined/false here despite being true for the rest of
// the translation unit - which desyncs this file's declarations from FBTCPSocket.m's own
// #if TARGET_OS_WATCH branch.
#import <TargetConditionals.h>

#if TARGET_OS_WATCH
@import Foundation;
// A textual import, not `@import Network;` - older Xcode/watchOS SDK combinations (verified:
// Xcode 15.4/watchOS 10.5) fail to expose nw_listener_t/nw_connection_t and friends through the
// Network module map on watchOS, even though the underlying API has existed since watchOS 5.0.
#import <Network/Network.h>
#else
#import "GCDAsyncSocket.h"
#endif

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_WATCH

// watchOS forbids BSD sockets, so this is backed by Network.framework instead of GCDAsyncSocket -
// hence a differently-shaped, push-style delegate protocol.
@protocol FBTCPSocketDelegate <NSObject>

/**
 The callback which is fired on new TCP client connection

 @param newClient The newly connected client
 */
- (void)didClientConnect:(nw_connection_t)newClient;

/**
 The callback which is fired when the TCP server receives data from a connected client

 @param client The client, which sent the data
 @param data The received data
*/
- (void)client:(nw_connection_t)client didReceiveData:(NSData *)data;

/**
 The callback which is fired when TCP client disconnects

 @param client The actual disconnected client
 */
- (void)didClientDisconnect:(nw_connection_t)client;

@end

#else

@protocol FBTCPSocketDelegate

/**
 The callback which is fired on new TCP client connection

 @param newClient The newly connected socket
 */
- (void)didClientConnect:(GCDAsyncSocket *)newClient;

/**
 The callback which is fired when the TCP server receives a data from a connected client

 @param client The client, which sent the data
*/
- (void)didClientSendData:(GCDAsyncSocket *)client;

/**
 The callback which is fired when TCP client disconnects

 @param client The actual diconnected client
 */
- (void)didClientDisconnect:(GCDAsyncSocket *)client;

@end

#endif


@interface FBTCPSocket : NSObject

#if __has_feature(objc_arc_weak)
@property (nullable, nonatomic, weak) id<FBTCPSocketDelegate> delegate;
#else
@property (nullable, nonatomic, assign) id<FBTCPSocketDelegate> delegate;
#endif

/**
 Creates TCP socket isntance which is going to be started on the specified port

 @param port The actual port number
 @return self instance
 */
- (instancetype)initWithPort:(uint16_t)port;

/**
 Starts TCP socket listener on the specified port

 @param error The alias to the actual startup error  descirption or nil if the socket has started and is listening
 @return NO If there was an error
 */
- (BOOL)startWithError:(NSError **)error;

/**
 Stops the socket if it is running
 */
- (void)stop;

#if TARGET_OS_WATCH
/**
 Writes data to the given connected client

 @param data The data to send
 @param client The destination client, as received via -didClientConnect: or -client:didReceiveData:
 */
- (void)writeData:(NSData *)data toClient:(nw_connection_t)client;

/**
 Like -writeData:toClient:, but invokes completion once the send actually goes out. Use this
 before cancelling the connection - nw_connection_send is async, so cancelling right away can
 drop the write before it's sent.

 @param data The data to send
 @param client The destination client
 @param completion Called once the send attempt finishes
 */
- (void)writeData:(NSData *)data toClient:(nw_connection_t)client completion:(nullable void (^)(void))completion;
#endif

@end

NS_ASSUME_NONNULL_END
