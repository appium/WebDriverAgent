/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTCPSocket.h"

#import "FBLogger.h"

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
    for (NSUInteger i = 0; i < [self.connectedClients count]; i++) {
      [[self.connectedClients objectAtIndex:i] disconnect];
    }
  }

  [self.listeningSocket disconnect];
}

@end


@implementation FBTCPSocket(AsyncSocket)

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
  NSString *host = [newSocket connectedHost];
  UInt16 port = [newSocket connectedPort];
  [FBLogger logFmt:@"Starting screenshots broadcast to %@:%d", host, port];

  @synchronized(self.connectedClients) {
    [self.connectedClients addObject:newSocket];
    [self.delegate didClientConnect:newSocket activeClients:self.connectedClients.copy];
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
  @synchronized(self.connectedClients) {
    [self.connectedClients removeObject:sock];
    [self.delegate didClientDisconnect:self.connectedClients.copy];
  }
}

@end
