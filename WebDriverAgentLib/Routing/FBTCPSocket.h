/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "GCDAsyncSocket.h"

NS_ASSUME_NONNULL_BEGIN

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


@interface FBTCPSocket : NSObject

@property (nullable, nonatomic) id<FBTCPSocketDelegate> delegate;

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
@end

NS_ASSUME_NONNULL_END
