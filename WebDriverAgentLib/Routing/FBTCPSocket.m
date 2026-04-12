/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBTCPSocket.h"


@interface FBTCPSocket()
@property (readonly, nonatomic) dispatch_queue_t socketQueue;
@property (readonly, nonatomic) GCDAsyncSocket *listeningSocket;
@property (readonly, nonatomic) NSMutableArray *connectedClients;
@property (readonly, nonatomic) uint16_t port;
@end


@interface FBTCPSocket(AsyncSocket) <GCDAsyncSocketDelegate>

@end


@implementation FBTCPSocket

- (instancetype)initWithPort:(uint16_t)port
{
  if ((self = [super init])) {
    _socketQueue = dispatch_queue_create("socketQueue", NULL);
    _listeningSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    _connectedClients = [[NSMutableArray alloc] initWithCapacity:1];
    _port = port;
    _delegate = nil;
  }
  return self;
}

- (BOOL)startWithError:(NSError **)error
{
  if (![self.listeningSocket acceptOnPort:self.port error:error]) {
    return NO;;
  }

  return YES;
}

- (void)stop
{
  @synchronized(self.connectedClients) {
    NSArray *clients = self.connectedClients.copy;
    [self.connectedClients removeAllObjects];
    for (GCDAsyncSocket *client in clients) {
      [client disconnect];
    }
  }

  self.delegate = nil;
  [self.listeningSocket disconnect];
}

@end


@implementation FBTCPSocket(AsyncSocket)

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
  @synchronized(self.connectedClients) {
    [self.connectedClients addObject:newSocket];
  }
  id<FBTCPSocketDelegate> delegate = self.delegate;
  if (nil != delegate) {
    [delegate didClientConnect:newSocket];
  }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  id<FBTCPSocketDelegate> delegate = self.delegate;
  if (nil != delegate) {
    [delegate didClientSendData:sock];
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
  @synchronized(self.connectedClients) {
    [self.connectedClients removeObject:sock];
  }
  id<FBTCPSocketDelegate> delegate = self.delegate;
  if (nil != delegate) {
    [delegate didClientDisconnect:sock];
  }
}

@end
