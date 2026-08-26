/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

@import Foundation;
// A textual import, not `@import Network;` - older Xcode/watchOS SDK combinations (verified:
// Xcode 15.4/watchOS 10.5) fail to expose nw_listener_t/nw_connection_t and friends through the
// Network module map on watchOS, even though the underlying API has existed since watchOS 5.0.
// Kept unconditional (rather than gated to watchOS) since it also builds cleanly on iOS/tvOS.
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

// Backed by Network.framework rather than BSD sockets on every platform, since watchOS forbids
// BSD sockets outright and there is no reason to keep a second, socket-based implementation
// around just for iOS/tvOS.
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


@interface FBTCPSocket : NSObject

#if __has_feature(objc_arc_weak)
@property (nullable, nonatomic, weak) id<FBTCPSocketDelegate> delegate;
#else
@property (nullable, nonatomic, assign) id<FBTCPSocketDelegate> delegate;
#endif

/**
 The port this socket is listening on. Equal to the port passed to -initWithPort: unless that was
 0 ("let the system assign a port"), in which case this reflects the actually assigned port once
 -startWithError: has returned successfully.
 */
@property (nonatomic, readonly) uint16_t port;

/**
 The local IP address to bind the listener to, or nil to listen on all interfaces. Must be set
 before -startWithError: is called.
 */
@property (nonatomic, copy, nullable) NSString *interface;

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
 @param completion Called once the send attempt finishes. `didSucceed` is NO if the send failed
        (e.g. the peer went away mid-write), in which case nothing was delivered and the caller
        must not treat the connection as usable.
 */
- (void)writeData:(NSData *)data toClient:(nw_connection_t)client completion:(nullable void (^)(BOOL didSucceed))completion;

@end

NS_ASSUME_NONNULL_END
