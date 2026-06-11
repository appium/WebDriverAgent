/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBroadcastControlServer.h"

#include <time.h>

#import "FBLogger.h"
#import "GCDAsyncSocket.h"

static const long TAG_HEADER = 1;
static const long TAG_PAYLOAD = 2;

// The extension heartbeats every 2s; treat the broadcast as dead after 6s of silence.
static const NSTimeInterval WATCHDOG_INTERVAL = 3.0;
static const NSTimeInterval STALENESS_TIMEOUT = 6.0;

@interface FBBroadcastControlServer () <GCDAsyncSocketDelegate>

@property (nonatomic, readonly) uint16_t port;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, nullable) GCDAsyncSocket *listenSocket;
@property (nonatomic, nullable) GCDAsyncSocket *extensionSocket;
@property (nonatomic, nullable) dispatch_source_t watchdogTimer;
@property (atomic, readwrite) BOOL isExtensionConnected;
@property (nonatomic) uint64_t lastMessageAtMs;
@property (nonatomic) FBBroadcastMessageHeader pendingHeader;

@end

@implementation FBBroadcastControlServer

- (instancetype)initWithPort:(uint16_t)port
{
  if ((self = [super init])) {
    _port = port;
    _queue = dispatch_queue_create("wda.broadcast.control", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (BOOL)startWithError:(NSError **)error
{
  self.listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
  // Loopback only: the control port must never be reachable from the network.
  if (![self.listenSocket acceptOnInterface:@"127.0.0.1" port:self.port error:error]) {
    self.listenSocket = nil;
    return NO;
  }
  [FBLogger logFmt:@"Broadcast control server is listening on 127.0.0.1:%d", self.port];
  return YES;
}

- (void)stop
{
  dispatch_sync(self.queue, ^{
    [self stopWatchdog];
    [self dropExtensionSocketLocked];
    self.listenSocket.delegate = nil;
    [self.listenSocket disconnect];
    self.listenSocket = nil;
  });
}

#pragma mark - Outgoing messages

- (void)sendMessage:(nullable NSData *)message
{
  if (nil == message) {
    return;
  }
  dispatch_async(self.queue, ^{
    [self.extensionSocket writeData:(NSData *)message withTimeout:-1 tag:0];
  });
}

- (void)sendSessionAdd:(uint32_t)sessionId configuration:(NSDictionary<NSString *, id> *)configuration
{
  [self sendMessage:FBBroadcastEncodeJSONMessage(FBBroadcastMessageTypeSessionAdd, sessionId, configuration)];
}

- (void)sendSessionRemove:(uint32_t)sessionId
{
  [self sendMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeSessionRemove, sessionId, nil)];
}

- (void)sendKeyframeRequest:(uint32_t)sessionId
{
  [self sendMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeKeyframeRequest, sessionId, nil)];
}

- (void)sendStopBroadcast
{
  [self sendMessage:FBBroadcastEncodeMessage(FBBroadcastMessageTypeStopBroadcast, 0, nil)];
}

#pragma mark - Watchdog

- (void)startWatchdog
{
  [self stopWatchdog];
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
  if (nil == timer) {
    return;
  }
  dispatch_source_set_timer(timer,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(WATCHDOG_INTERVAL * NSEC_PER_SEC)),
                            (uint64_t)(WATCHDOG_INTERVAL * NSEC_PER_SEC),
                            (uint64_t)(0.5 * NSEC_PER_SEC));
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(timer, ^{
    [weakSelf checkStaleness];
  });
  dispatch_resume(timer);
  self.watchdogTimer = timer;
}

- (void)stopWatchdog
{
  dispatch_source_t timer = self.watchdogTimer;
  if (nil != timer) {
    dispatch_source_cancel(timer);
    self.watchdogTimer = nil;
  }
}

- (void)checkStaleness
{
  if (nil == self.extensionSocket) {
    return;
  }
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  if (nowMs - self.lastMessageAtMs > (uint64_t)(STALENESS_TIMEOUT * 1000)) {
    [FBLogger log:@"The broadcast extension went silent; dropping the connection"];
    [self dropExtensionSocketLocked];
    [self.delegate broadcastServerDidDisconnect];
  }
}

- (void)dropExtensionSocketLocked
{
  if (nil == self.extensionSocket) {
    return;
  }
  GCDAsyncSocket *socket = self.extensionSocket;
  self.extensionSocket = nil;
  self.isExtensionConnected = NO;
  socket.delegate = nil;
  [socket disconnect];
  [self stopWatchdog];
}

#pragma mark - Incoming messages

- (void)handleMessageWithHeader:(FBBroadcastMessageHeader)header payload:(NSData *)payload
{
  id<FBBroadcastControlServerDelegate> delegate = self.delegate;
  switch (header.type) {
    case FBBroadcastMessageTypeHello: {
      NSDictionary *helloInfo = FBBroadcastParseJSONPayload(payload) ?: @{};
      self.isExtensionConnected = YES;
      [delegate broadcastServerDidConnect:helloInfo];
      return;
    }
    case FBBroadcastMessageTypeHeartbeat: {
      NSDictionary *heartbeat = FBBroadcastParseJSONPayload(payload);
      if (nil != heartbeat) {
        [delegate broadcastServerDidReceiveHeartbeat:heartbeat];
      }
      return;
    }
    case FBBroadcastMessageTypeStatus: {
      NSDictionary *status = FBBroadcastParseJSONPayload(payload);
      if (nil != status) {
        [delegate broadcastServerDidReceiveStatus:status];
      }
      return;
    }
    case FBBroadcastMessageTypeSessionError: {
      NSDictionary *info = FBBroadcastParseJSONPayload(payload);
      NSString *message = [info[FBBroadcastKeyMessage] isKindOfClass:NSString.class]
        ? (NSString *)info[FBBroadcastKeyMessage]
        : @"The extension reported a session failure";
      [delegate broadcastServerDidReceiveSessionError:message forSession:header.sessionId];
      return;
    }
    case FBBroadcastMessageTypeVideoParams:
      [delegate broadcastServerDidReceiveParameterSets:payload forSession:header.sessionId];
      return;
    case FBBroadcastMessageTypeAudioParams: {
      // The payload must be a plausible RFC 7845 identification header ("OpusHead" magic).
      static const char opusHeadMagic[8] = {'O', 'p', 'u', 's', 'H', 'e', 'a', 'd'};
      if (payload.length < 19 || 0 != memcmp(payload.bytes, opusHeadMagic, sizeof(opusHeadMagic))) {
        [FBLogger logFmt:@"Session %u: malformed AUDIO_PARAMS payload", header.sessionId];
        return;
      }
      [delegate broadcastServerDidReceiveAudioParams:payload forSession:header.sessionId];
      return;
    }
    case FBBroadcastMessageTypeAudioFrame: {
      uint64_t audioPtsUs = 0;
      NSData *opusPacket = nil;
      if (!FBBroadcastParseAudioFramePayload(payload, &audioPtsUs, &opusPacket)) {
        [FBLogger logFmt:@"Session %u: malformed AUDIO_FRAME payload", header.sessionId];
        return;
      }
      [delegate broadcastServerDidReceiveAudioPacket:(NSData *)opusPacket
                                               ptsUs:audioPtsUs
                                          forSession:header.sessionId];
      return;
    }
    case FBBroadcastMessageTypeVideoFrame: {
      uint64_t ptsUs = 0;
      BOOL isKeyFrame = NO;
      uint8_t orientation = 0;
      NSData *annexB = nil;
      if (!FBBroadcastParseVideoFramePayload(payload, &ptsUs, &isKeyFrame, &orientation, &annexB)) {
        [FBLogger logFmt:@"Session %u: malformed VIDEO_FRAME payload", header.sessionId];
        return;
      }
      [delegate broadcastServerDidReceiveFrame:(NSData *)annexB
                                    isKeyFrame:isKeyFrame
                                         ptsUs:ptsUs
                                   orientation:orientation
                                    forSession:header.sessionId];
      return;
    }
    default:
      [FBLogger logFmt:@"Ignoring an unexpected broadcast control message of type 0x%02x", header.type];
      return;
  }
}

#pragma mark - <GCDAsyncSocketDelegate>

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
  // A reconnecting extension supersedes the previous connection.
  if (nil != self.extensionSocket) {
    [FBLogger log:@"A new broadcast extension connection replaces the previous one"];
    [self dropExtensionSocketLocked];
    [self.delegate broadcastServerDidDisconnect];
  }
  [FBLogger logFmt:@"The broadcast extension connected from %@:%d", newSocket.connectedHost, newSocket.connectedPort];
  self.extensionSocket = newSocket;
  self.lastMessageAtMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  [self startWatchdog];
  [newSocket readDataToLength:FBBroadcastHeaderLength withTimeout:-1 tag:TAG_HEADER];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (sock != self.extensionSocket) {
    return;
  }
  self.lastMessageAtMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;

  if (tag == TAG_HEADER) {
    FBBroadcastMessageHeader header;
    if (!FBBroadcastParseHeader(data, &header)) {
      [FBLogger log:@"Malformed broadcast control message header; dropping the connection"];
      [self dropExtensionSocketLocked];
      [self.delegate broadcastServerDidDisconnect];
      return;
    }
    self.pendingHeader = header;
    if (header.payloadLength == 0) {
      [self handleMessageWithHeader:header payload:NSData.data];
      [sock readDataToLength:FBBroadcastHeaderLength withTimeout:-1 tag:TAG_HEADER];
    } else {
      [sock readDataToLength:header.payloadLength withTimeout:-1 tag:TAG_PAYLOAD];
    }
    return;
  }
  [self handleMessageWithHeader:self.pendingHeader payload:data];
  [sock readDataToLength:FBBroadcastHeaderLength withTimeout:-1 tag:TAG_HEADER];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)error
{
  if (sock != self.extensionSocket) {
    return;
  }
  [FBLogger logFmt:@"The broadcast extension disconnected: %@", error.description ?: @"closed"];
  self.extensionSocket = nil;
  self.isExtensionConnected = NO;
  [self stopWatchdog];
  [self.delegate broadcastServerDidDisconnect];
}

@end
