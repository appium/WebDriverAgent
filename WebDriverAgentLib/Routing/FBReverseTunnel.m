/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBReverseTunnel.h"
#import <Network/Network.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import "FBLogger.h"

/** Maximum allowed payload size (matches Appium HTTP server limit) */
static const uint32_t FBReverseTunnelMaxPayloadSize = 1024 * 1024 * 1024; // 1 GB

/** Size of the frame header (4-byte length + 4-byte request ID) */
static const uint32_t FBReverseTunnelHeaderSize = 8;

/** Receive buffer size for local HTTP forwarding */
static const size_t FBReverseTunnelRecvBufferSize = 65536; // 64 KB

/** Initial delay before reconnecting after a connection failure */
static const uint64_t FBReverseTunnelInitialReconnectDelay = 5; // seconds

/** Maximum reconnect delay (exponential backoff cap) */
static const uint64_t FBReverseTunnelMaxReconnectDelay = 60; // seconds

static NSString *_relayHost;
static NSInteger _relayPort;
static NSUInteger _localPort;
static uint64_t _currentReconnectDelay;

@implementation FBReverseTunnel

#pragma mark - Public

+ (void)startWithHost:(NSString *)host
                 port:(NSInteger)port
            localPort:(NSUInteger)localPort
{
  _relayHost = host;
  _relayPort = port;
  _localPort = localPort;
  _currentReconnectDelay = FBReverseTunnelInitialReconnectDelay;
  [self connect];
}

#pragma mark - Connection Management

+ (void)connect
{
  [FBLogger logFmt:@"[ReverseTunnel] Connecting to relay %@:%ld", _relayHost, (long)_relayPort];

  nw_endpoint_t endpoint = nw_endpoint_create_host(
    [_relayHost UTF8String],
    [[NSString stringWithFormat:@"%ld", (long)_relayPort] UTF8String]
  );
  nw_parameters_t params = nw_parameters_create_secure_tcp(
    NW_PARAMETERS_DISABLE_PROTOCOL,
    NW_PARAMETERS_DEFAULT_CONFIGURATION
  );
  nw_connection_t conn = nw_connection_create(endpoint, params);
  nw_connection_set_queue(conn, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

  nw_connection_set_state_changed_handler(conn, ^(nw_connection_state_t state, nw_error_t error) {
    switch (state) {
      case nw_connection_state_ready:
        [FBLogger logFmt:@"[ReverseTunnel] Connected to relay"];
        _currentReconnectDelay = FBReverseTunnelInitialReconnectDelay; // reset backoff on success
        [self readFrameFromConnection:conn];
        break;
      case nw_connection_state_failed:
        [FBLogger logFmt:@"[ReverseTunnel] Connection failed: %@, retrying in %llus",
         error, FBReverseTunnelReconnectDelay];
        [self scheduleReconnect];
        break;
      case nw_connection_state_cancelled:
        [FBLogger logFmt:@"[ReverseTunnel] Connection cancelled"];
        break;
      case nw_connection_state_waiting:
        [FBLogger logFmt:@"[ReverseTunnel] Waiting for network path: %@", error];
        break;
      case nw_connection_state_preparing:
        [FBLogger logFmt:@"[ReverseTunnel] Preparing..."];
        break;
      default:
        break;
    }
  });

  nw_connection_start(conn);
}

+ (void)scheduleReconnect
{
  uint64_t delay = _currentReconnectDelay;
  [FBLogger logFmt:@"[ReverseTunnel] Reconnecting in %llus (backoff)", delay];
  dispatch_after(
    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
    dispatch_get_global_queue(0, 0),
    ^{ [self connect]; }
  );
  // Exponential backoff: double the delay, cap at max
  _currentReconnectDelay = MIN(_currentReconnectDelay * 2, FBReverseTunnelMaxReconnectDelay);
}

#pragma mark - Frame Reading (8-byte header: 4-byte length + 4-byte request ID)

+ (void)readFrameFromConnection:(nw_connection_t)conn
{
  nw_connection_receive(conn, FBReverseTunnelHeaderSize, FBReverseTunnelHeaderSize, ^(dispatch_data_t hdrData, nw_content_context_t ctx,
                                       bool isComplete, nw_error_t error) {
    if (error || !hdrData) {
      [FBLogger logFmt:@"[ReverseTunnel] Header read error, reconnecting"];
      nw_connection_cancel(conn);
      [self scheduleReconnect];
      return;
    }

    __block uint32_t payloadLen = 0, reqId = 0;
    dispatch_data_apply(hdrData, ^bool(dispatch_data_t region, size_t offset,
                                        const void *buffer, size_t size) {
      const uint8_t *b = buffer;
      if (size >= FBReverseTunnelHeaderSize) {
        payloadLen = (uint32_t)b[0]<<24 | (uint32_t)b[1]<<16 | (uint32_t)b[2]<<8 | b[3];
        reqId      = (uint32_t)b[4]<<24 | (uint32_t)b[5]<<16 | (uint32_t)b[6]<<8 | b[7];
      }
      return true;
    });

    if (payloadLen == 0 || payloadLen > FBReverseTunnelMaxPayloadSize) {
      [FBLogger logFmt:@"[ReverseTunnel] Invalid payload length: %u, skipping", payloadLen];
      [self readFrameFromConnection:conn];
      return;
    }

    [self readPayload:payloadLen requestId:reqId fromConnection:conn];
  });
}

+ (void)readPayload:(uint32_t)length
           requestId:(uint32_t)reqId
      fromConnection:(nw_connection_t)conn
{
  nw_connection_receive(conn, length, length, ^(dispatch_data_t bodyData,
                                                 nw_content_context_t ctx,
                                                 bool isComplete, nw_error_t error) {
    if (error || !bodyData) {
      [FBLogger logFmt:@"[ReverseTunnel] Payload read error, reconnecting"];
      nw_connection_cancel(conn);
      [self scheduleReconnect];
      return;
    }

    NSData *requestData = [self extractData:bodyData];
    [self forwardRequest:requestData requestId:reqId throughConnection:conn];
  });
}

+ (NSData *)extractData:(dispatch_data_t)dispatchData
{
  NSMutableData *result = [NSMutableData data];
  dispatch_data_apply(dispatchData, ^bool(dispatch_data_t region, size_t offset,
                                          const void *buffer, size_t size) {
    [result appendBytes:buffer length:size];
    return true;
  });
  return result;
}

#pragma mark - HTTP Forwarding (POSIX socket to localhost)

+ (void)forwardRequest:(NSData *)httpRequest
             requestId:(uint32_t)reqId
     throughConnection:(nw_connection_t)conn
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)_localPort);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    NSMutableData *response = [NSMutableData data];
    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
      send(sock, httpRequest.bytes, httpRequest.length, 0);

      uint8_t buf[FBReverseTunnelRecvBufferSize];
      while (1) {
        ssize_t n = recv(sock, buf, FBReverseTunnelRecvBufferSize, 0);
        if (n <= 0) break;
        [response appendBytes:buf length:n];
      }
    } else {
      const char *err = "HTTP/1.1 502 Bad Gateway\r\n\r\nLocal WDA unreachable";
      [response appendBytes:err length:strlen(err)];
    }
    close(sock);

    [self sendResponse:response requestId:reqId throughConnection:conn];
  });
}

#pragma mark - Response Framing & Sending

+ (void)sendResponse:(NSData *)response
            requestId:(uint32_t)reqId
    throughConnection:(nw_connection_t)conn
{
  uint32_t rLen = (uint32_t)response.length;
  uint8_t hdr[8] = {
    (rLen>>24)&0xFF, (rLen>>16)&0xFF, (rLen>>8)&0xFF, rLen&0xFF,
    (reqId>>24)&0xFF, (reqId>>16)&0xFF, (reqId>>8)&0xFF, reqId&0xFF
  };

  dispatch_data_t hdrOut = dispatch_data_create(hdr, 8, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  dispatch_data_t bodyOut = dispatch_data_create(response.bytes, response.length,
                                                  NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  dispatch_data_t fullOut = dispatch_data_create_concat(hdrOut, bodyOut);

  nw_connection_send(conn, fullOut, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                     ^(nw_error_t sendError) {
    if (sendError) {
      [FBLogger logFmt:@"[ReverseTunnel] Send error: %@", sendError];
      return;
    }
    [self readFrameFromConnection:conn];
  });
}

@end
