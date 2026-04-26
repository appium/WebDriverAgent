/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBReverseTunnel.h"
#import <Network/Network.h>
#import "FBConfiguration.h"
#import "FBLogger.h"

/** Maximum allowed payload size to guard against corrupted length headers */
static const uint32_t FBReverseTunnelMaxPayloadSize = 10 * 1024 * 1024; // 10 MB

/** Delay before reconnecting after a connection failure */
static const uint64_t FBReverseTunnelReconnectDelay = 5; // seconds

static NSUInteger _localPort;

@implementation FBReverseTunnel

#pragma mark - Public

+ (void)startIfConfiguredWithLocalPort:(NSUInteger)localPort
{
  NSString *relayHost = FBConfiguration.relayHost;
  if (!relayHost) {
    return;  // Reverse tunnel not configured — default behavior unchanged
  }
  _localPort = localPort;
  [self connectToRelayHost:relayHost port:FBConfiguration.relayPort];
}

#pragma mark - Connection Management

+ (void)connectToRelayHost:(NSString *)host port:(NSInteger)port
{
  [FBLogger logFmt:@"[ReverseTunnel] Connecting to relay %@:%ld", host, (long)port];

  nw_endpoint_t endpoint = nw_endpoint_create_host(
    [host UTF8String],
    [[NSString stringWithFormat:@"%ld", (long)port] UTF8String]
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
        [self readFrameFromConnection:conn];
        break;
      case nw_connection_state_failed:
        [FBLogger logFmt:@"[ReverseTunnel] Connection failed: %@, retrying in %llus",
         error, FBReverseTunnelReconnectDelay];
        [self scheduleReconnectToHost:host port:port];
        break;
      case nw_connection_state_waiting:
        [FBLogger logFmt:@"[ReverseTunnel] Waiting for network path"];
        break;
      default:
        break;
    }
  });

  nw_connection_start(conn);
}

+ (void)scheduleReconnectToHost:(NSString *)host port:(NSInteger)port
{
  dispatch_after(
    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBReverseTunnelReconnectDelay * NSEC_PER_SEC)),
    dispatch_get_global_queue(0, 0),
    ^{ [self connectToRelayHost:host port:port]; }
  );
}

+ (void)handleDisconnection:(nw_connection_t)conn
{
  nw_connection_cancel(conn);
  NSString *host = FBConfiguration.relayHost;
  if (host) {
    [self scheduleReconnectToHost:host port:FBConfiguration.relayPort];
  }
}

#pragma mark - Frame Reading (4-byte length-prefixed protocol)

+ (void)readFrameFromConnection:(nw_connection_t)conn
{
  // Read 4-byte big-endian length header
  nw_connection_receive(conn, 4, 4, ^(dispatch_data_t lenData, nw_content_context_t ctx,
                                       bool isComplete, nw_error_t error) {
    if (error || !lenData) {
      [FBLogger logFmt:@"[ReverseTunnel] Header read error, reconnecting"];
      [self handleDisconnection:conn];
      return;
    }

    uint32_t payloadLen = [self parsePayloadLength:lenData];
    if (payloadLen == 0 || payloadLen > FBReverseTunnelMaxPayloadSize) {
      [FBLogger logFmt:@"[ReverseTunnel] Invalid payload length: %u, skipping", payloadLen];
      [self readFrameFromConnection:conn];
      return;
    }

    [self readPayload:payloadLen fromConnection:conn];
  });
}

+ (uint32_t)parsePayloadLength:(dispatch_data_t)data
{
  __block uint32_t length = 0;
  dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset,
                                   const void *buffer, size_t size) {
    if (size >= 4) {
      memcpy(&length, buffer, 4);
      length = ntohl(length);
    }
    return true;
  });
  return length;
}

+ (void)readPayload:(uint32_t)length fromConnection:(nw_connection_t)conn
{
  nw_connection_receive(conn, length, length, ^(dispatch_data_t bodyData,
                                                 nw_content_context_t ctx,
                                                 bool isComplete, nw_error_t error) {
    if (error || !bodyData) {
      [FBLogger logFmt:@"[ReverseTunnel] Payload read error, reconnecting"];
      [self handleDisconnection:conn];
      return;
    }

    NSData *requestData = [self extractData:bodyData];
    [self forwardHTTPRequest:requestData throughConnection:conn];
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

#pragma mark - HTTP Request Parsing

+ (NSDictionary *)parseHTTPRequest:(NSData *)data
{
  NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (!raw) return nil;

  NSArray *lines = [raw componentsSeparatedByString:@"\r\n"];
  if (lines.count == 0) return nil;

  NSArray *requestLine = [lines[0] componentsSeparatedByString:@" "];
  if (requestLine.count < 2) return nil;

  NSString *method = requestLine[0];
  NSString *path = requestLine[1];

  // Extract body after \r\n\r\n
  NSData *body = nil;
  NSRange separator = [raw rangeOfString:@"\r\n\r\n"];
  if (separator.location != NSNotFound) {
    NSString *bodyStr = [raw substringFromIndex:separator.location + 4];
    if (bodyStr.length > 0) {
      body = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    }
  }

  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  result[@"method"] = method;
  result[@"path"] = path;
  if (body) result[@"body"] = body;
  return result;
}

#pragma mark - HTTP Forwarding

+ (void)forwardHTTPRequest:(NSData *)requestData throughConnection:(nw_connection_t)conn
{
  NSDictionary *parsed = [self parseHTTPRequest:requestData];
  if (!parsed) {
    [self readFrameFromConnection:conn];
    return;
  }

  NSURLRequest *localRequest = [self buildLocalRequestWithMethod:parsed[@"method"]
                                                           path:parsed[@"path"]
                                                           body:parsed[@"body"]];
  if (!localRequest) {
    [self readFrameFromConnection:conn];
    return;
  }

  [[[NSURLSession sharedSession] dataTaskWithRequest:localRequest
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *err) {
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResp ? httpResp.statusCode : 500;

    NSData *framedResponse = [self buildFramedResponse:data statusCode:statusCode];
    [self sendData:framedResponse throughConnection:conn];
  }] resume];
}

+ (NSURLRequest *)buildLocalRequestWithMethod:(NSString *)method
                                         path:(NSString *)path
                                         body:(NSData *)body
{
  NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:%lu%@",
                      (unsigned long)_localPort, path];
  NSURL *url = [NSURL URLWithString:urlStr];
  if (!url) return nil;

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = method;
  request.timeoutInterval = 60;
  if (body) {
    request.HTTPBody = body;
  }
  return request;
}

#pragma mark - Response Building & Sending

+ (NSData *)buildFramedResponse:(NSData *)body statusCode:(NSInteger)statusCode
{
  NSString *statusLine = [NSString stringWithFormat:@"HTTP/1.1 %ld OK\r\n", (long)statusCode];
  NSMutableString *headers = [NSMutableString stringWithString:statusLine];
  [headers appendString:@"Content-Type: application/json\r\n"];
  [headers appendFormat:@"Content-Length: %lu\r\n", (unsigned long)(body ? body.length : 0)];
  [headers appendString:@"\r\n"];

  NSMutableData *httpResponse = [NSMutableData dataWithData:
                                 [headers dataUsingEncoding:NSUTF8StringEncoding]];
  if (body) {
    [httpResponse appendData:body];
  }

  // Add 4-byte length prefix
  uint32_t framedLen = htonl((uint32_t)httpResponse.length);
  NSMutableData *framed = [NSMutableData dataWithBytes:&framedLen length:4];
  [framed appendData:httpResponse];
  return framed;
}

+ (void)sendData:(NSData *)data throughConnection:(nw_connection_t)conn
{
  dispatch_data_t sendData = dispatch_data_create(
    data.bytes, data.length,
    dispatch_get_global_queue(0, 0),
    DISPATCH_DATA_DESTRUCTOR_DEFAULT
  );
  nw_connection_send(conn, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                     ^(nw_error_t sendError) {
    if (sendError) {
      [FBLogger logFmt:@"[ReverseTunnel] Send error: %@", sendError];
    }
    [self readFrameFromConnection:conn];
  });
}

@end
