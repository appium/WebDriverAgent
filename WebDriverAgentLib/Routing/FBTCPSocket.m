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
@property (nullable, nonatomic) nw_listener_t listener;
@property (readonly, nonatomic) NSMutableArray<nw_connection_t> *connectedClients;
@end


@implementation FBTCPSocket

- (instancetype)initWithPort:(uint16_t)port
{
  if ((self = [super init])) {
    _socketQueue = dispatch_queue_create("socketQueue", NULL);
    _connectedClients = [[NSMutableArray alloc] initWithCapacity:1];
    _port = port;
    _delegate = nil;
  }
  return self;
}

- (BOOL)startWithError:(NSError **)error
{
  nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
                                                                NW_PARAMETERS_DEFAULT_CONFIGURATION);
  NSString *portString = [NSString stringWithFormat:@"%u", (unsigned int)self.port];
  // portString is always valid UTF8; -UTF8String is just declared nullable in general.
  const char * _Nonnull portCString = (const char * _Nonnull)portString.UTF8String;

  nw_listener_t listener;
  if (nil != self.interface) {
    const char * _Nonnull interfaceCString = (const char * _Nonnull)((NSString * _Nonnull)self.interface).UTF8String;
    nw_endpoint_t localEndpoint = nw_endpoint_create_host(interfaceCString, portCString);
    nw_parameters_set_local_endpoint(parameters, localEndpoint);
    // The port is already encoded in localEndpoint above - do not also pass it to
    // nw_listener_create_with_port, which would be ambiguous.
    listener = nw_listener_create(parameters);
  } else {
    listener = nw_listener_create_with_port(portCString, parameters);
  }
  if (nil == listener) {
    if (error) {
      *error = [NSError errorWithDomain:@"FBTCPSocket"
                                    code:1
                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to create the TCP listener"}];
    }
    return NO;
  }
  self.listener = listener;

  __weak typeof(self) weakSelf = self;
  nw_listener_set_queue(listener, self.socketQueue);
  nw_listener_set_new_connection_handler(listener, ^(nw_connection_t connection) {
    [weakSelf acceptConnection:connection];
  });

  dispatch_semaphore_t startupSemaphore = dispatch_semaphore_create(0);
  __block NSError *startupError = nil;
  nw_listener_set_state_changed_handler(listener, ^(nw_listener_state_t state, nw_error_t nwError) {
    // if/else, not switch: -Wswitch-enum, -Wswitch-default, and -Wcovered-switch-default can't
    // all be satisfied by one switch statement at once.
    if (nw_listener_state_ready == state) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf) {
        strongSelf->_port = nw_listener_get_port(listener);
      }
      dispatch_semaphore_signal(startupSemaphore);
    } else if (nw_listener_state_failed == state || nw_listener_state_cancelled == state) {
      // NSLocalizedDescriptionKey must be a string, not the underlying NSError itself, or
      // -[NSError localizedDescription] crashes trying to treat it as one.
      NSError *underlyingError = nwError ? (NSError *)CFBridgingRelease(nw_error_copy_cf_error(nwError)) : nil;
      if ([underlyingError.domain isEqualToString:NSPOSIXErrorDomain]) {
        // Surface POSIX errors (e.g. EADDRINUSE) directly, since callers like FBWebServer check
        // for them by domain/code on the top-level error to decide whether to retry another port.
        startupError = underlyingError;
      } else {
        NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
        userInfo[NSLocalizedDescriptionKey] = underlyingError.localizedDescription ?: @"The TCP listener failed to start";
        if (underlyingError) {
          userInfo[NSUnderlyingErrorKey] = underlyingError;
        }
        startupError = [NSError errorWithDomain:@"FBTCPSocket" code:2 userInfo:userInfo];
      }
      dispatch_semaphore_signal(startupSemaphore);
    }
  });
  nw_listener_start(listener);
  BOOL didStartInTime = 0 == dispatch_semaphore_wait(startupSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
  if (!didStartInTime) {
    startupError = [NSError errorWithDomain:@"FBTCPSocket"
                                        code:3
                                    userInfo:@{NSLocalizedDescriptionKey: @"Timed out while starting the TCP listener"}];
  }
  if (nil != startupError) {
    if (error) {
      *error = startupError;
    }
    // Cancel rather than just dropping our reference - otherwise a late ready/failed callback
    // can still fire and the port stays bound at the OS level even though the caller was told
    // startup failed.
    nw_listener_cancel(listener);
    self.listener = nil;
    return NO;
  }
  return YES;
}

- (void)acceptConnection:(nw_connection_t)connection
{
  @synchronized (self.connectedClients) {
    [self.connectedClients addObject:connection];
  }

  __weak typeof(self) weakSelf = self;
  nw_connection_set_queue(connection, self.socketQueue);
  nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t connectionError) {
    // Same reasoning as the listener state handler above.
    if (nw_connection_state_ready == state) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (nil == strongSelf) {
        return;
      }
      id<FBTCPSocketDelegate> delegate = strongSelf.delegate;
      if (nil != delegate) {
        [delegate didClientConnect:connection];
      }
      [strongSelf scheduleReceiveForConnection:connection];
    } else if (nw_connection_state_failed == state || nw_connection_state_cancelled == state) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      [strongSelf handleDisconnectForConnection:connection];
    }
  });
  nw_connection_start(connection);
}

- (void)scheduleReceiveForConnection:(nw_connection_t)connection
{
  __weak typeof(self) weakSelf = self;
  nw_connection_receive(connection, 1, UINT32_MAX, ^(dispatch_data_t  _Nullable content,
                                                       nw_content_context_t  _Nullable context,
                                                       bool isComplete,
                                                       nw_error_t  _Nullable receiveError) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (nil == strongSelf) {
      return;
    }
    if (nil != content) {
      dispatch_data_t nonnullContent = (dispatch_data_t _Nonnull)content;
      NSMutableData *data = [NSMutableData data];
      dispatch_data_apply(nonnullContent, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
        [data appendBytes:buffer length:size];
        return true;
      });
      if (data.length > 0) {
        id<FBTCPSocketDelegate> delegate = strongSelf.delegate;
        if (nil != delegate) {
          [delegate client:connection didReceiveData:data];
        }
      }
    }
    if (nil != receiveError || (isComplete && nil == content)) {
      [strongSelf handleDisconnectForConnection:connection];
      return;
    }
    [strongSelf scheduleReceiveForConnection:connection];
  });
}

- (void)handleDisconnectForConnection:(nw_connection_t)connection
{
  BOOL wasConnected;
  @synchronized (self.connectedClients) {
    wasConnected = [self.connectedClients containsObject:connection];
    [self.connectedClients removeObject:connection];
  }
  if (wasConnected) {
    id<FBTCPSocketDelegate> delegate = self.delegate;
    if (nil != delegate) {
      [delegate didClientDisconnect:connection];
    }
  }
}

- (void)writeData:(NSData *)data toClient:(nw_connection_t)client
{
  [self writeData:data toClient:client completion:nil];
}

- (void)writeData:(NSData *)data toClient:(nw_connection_t)client completion:(nullable void (^)(BOOL didSucceed))completion
{
  dispatch_data_t dispatchData = dispatch_data_create(data.bytes, data.length, self.socketQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  nw_connection_send(client, dispatchData, NW_CONNECTION_DEFAULT_STREAM_CONTEXT, false, ^(nw_error_t  _Nullable sendError) {
    if (completion) {
      // The send error must reach the caller: a failed write means the response never reached
      // the peer, and treating that as success would e.g. let the next pipelined request run
      // against a connection that can no longer answer it.
      completion(nil == sendError);
    }
  });
}

- (void)stop
{
  NSArray<nw_connection_t> *clients;
  @synchronized (self.connectedClients) {
    clients = self.connectedClients.copy;
    [self.connectedClients removeAllObjects];
  }
  // Cancel on socketQueue, the same queue every connection's send/receive is bound to (see
  // -acceptConnection:), so a write already issued just before -stop (e.g. a shutdown route's
  // response) is processed before the cancellation rather than racing it.
  dispatch_async(self.socketQueue, ^{
    for (nw_connection_t client in clients) {
      nw_connection_cancel(client);
    }
  });

  self.delegate = nil;
  nw_listener_t listener = self.listener;
  if (nil != listener) {
    nw_listener_cancel((nw_listener_t _Nonnull)listener);
    self.listener = nil;
  }
}

@end
