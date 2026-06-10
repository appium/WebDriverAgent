/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBExtBroadcastClient.h"

#include <time.h>

#import "FBBroadcastProtocol.h"
#import "FBExtLogging.h"
#import "GCDAsyncSocket.h"

static const long TAG_HEADER = 1;
static const long TAG_PAYLOAD = 2;

static const NSUInteger CONNECT_ATTEMPTS = 3;
static const NSTimeInterval CONNECT_RETRY_DELAY = 1.0;
static const NSTimeInterval CONNECT_TIMEOUT = 5.0;
static const NSTimeInterval HEARTBEAT_INTERVAL = 2.0;
// Loopback writes should never back up this far; if they do, WDA is wedged - shed delta frames.
static const size_t MAX_OUTSTANDING_WRITE_BYTES = 4 * 1024 * 1024;

static NSString *const FBExtClientErrorDomain = @"com.facebook.WebDriverAgent.FBExtBroadcastClient";

@interface FBExtBroadcastClient () <GCDAsyncSocketDelegate>

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, nullable) GCDAsyncSocket *socket;
@property (nonatomic, nullable) dispatch_source_t heartbeatTimer;
@property (nonatomic) NSMutableDictionary<NSNumber *, FBExtSessionPipeline *> *pipelines;
@property (atomic, copy, readwrite) NSDictionary<NSNumber *, FBExtSessionPipeline *> *activePipelines;
@property (nonatomic) NSUInteger remainingConnectAttempts;
@property (atomic) BOOL stopped;
@property (atomic) BOOL connected;
@property (nonatomic) size_t outstandingWriteBytes;
@property (nonatomic) FBBroadcastMessageHeader pendingHeader;
// Previous heartbeat totals used to derive per-second rates (queue-confined).
@property (nonatomic, nullable) NSDictionary<NSString *, NSDictionary *> *previousPipelineTotals;
@property (nonatomic) uint64_t previousFramesReceived;
@property (nonatomic) uint64_t lastHeartbeatAtMs;

@end

static double FBExtRatePerSec(double delta, double intervalSec)
{
  return round(delta / intervalSec * 10) / 10;
}

@implementation FBExtBroadcastClient

- (instancetype)init
{
  if ((self = [super init])) {
    _queue = dispatch_queue_create("wda.broadcast.client", DISPATCH_QUEUE_SERIAL);
    _pipelines = [NSMutableDictionary dictionary];
    _activePipelines = @{};
    _remainingConnectAttempts = CONNECT_ATTEMPTS;
  }
  return self;
}

- (void)start
{
  dispatch_async(self.queue, ^{
    [self connect];
  });
}

- (void)connect
{
  if (self.stopped) {
    return;
  }
  self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
  NSError *error;
  if (![self.socket connectToHost:@"127.0.0.1" onPort:FBBroadcastDefaultControlPort
                      withTimeout:CONNECT_TIMEOUT error:&error]) {
    FBExtLogError("Cannot start connecting to WDA: %{public}@", error.description);
    [self scheduleReconnectOrGiveUp:error];
  }
}

- (void)scheduleReconnectOrGiveUp:(nullable NSError *)error
{
  if (self.stopped) {
    return;
  }
  if (self.remainingConnectAttempts == 0) {
    NSError *permanentError = error
      ?: [NSError errorWithDomain:FBExtClientErrorDomain
                             code:1
                         userInfo:@{NSLocalizedDescriptionKey: @"Lost the connection to WebDriverAgent"}];
    [self.delegate broadcastClient:self didFailPermanently:permanentError];
    return;
  }
  self.remainingConnectAttempts -= 1;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(CONNECT_RETRY_DELAY * NSEC_PER_SEC)),
                 self.queue, ^{
    [self connect];
  });
}

- (void)shutdown
{
  self.stopped = YES;
  dispatch_async(self.queue, ^{
    [self stopHeartbeat];
    for (FBExtSessionPipeline *pipeline in self.pipelines.allValues) {
      [pipeline teardown];
    }
    [self.pipelines removeAllObjects];
    self.activePipelines = @{};
    self.socket.delegate = nil;
    [self.socket disconnect];
    self.socket = nil;
  });
}

#pragma mark - <FBExtMessageSink>

- (void)sendProtocolMessage:(NSData *)message isDroppable:(BOOL)droppable
{
  dispatch_async(self.queue, ^{
    if (!self.connected || nil == self.socket) {
      return;
    }
    if (droppable && self.outstandingWriteBytes > MAX_OUTSTANDING_WRITE_BYTES) {
      return;
    }
    self.outstandingWriteBytes += message.length;
    [self.socket writeData:message withTimeout:-1 tag:(long)message.length];
  });
}

#pragma mark - Heartbeat

- (void)startHeartbeat
{
  [self stopHeartbeat];
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
  if (nil == timer) {
    return;
  }
  dispatch_source_set_timer(timer,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HEARTBEAT_INTERVAL * NSEC_PER_SEC)),
                            (uint64_t)(HEARTBEAT_INTERVAL * NSEC_PER_SEC),
                            (uint64_t)(0.2 * NSEC_PER_SEC));
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(timer, ^{
    [weakSelf sendHeartbeat];
  });
  dispatch_resume(timer);
  self.heartbeatTimer = timer;
}

- (void)stopHeartbeat
{
  dispatch_source_t timer = self.heartbeatTimer;
  if (nil != timer) {
    dispatch_source_cancel(timer);
    self.heartbeatTimer = nil;
  }
}

- (void)sendHeartbeat
{
  uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  double intervalSec = self.lastHeartbeatAtMs > 0
    ? MAX(0.001, (double)(nowMs - self.lastHeartbeatAtMs) / 1000.0)
    : HEARTBEAT_INTERVAL;
  uint64_t framesReceived = self.framesReceived;

  NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{
    FBBroadcastKeyState: self.paused ? @"paused" : @"active",
    FBBroadcastKeyFramesReceived: @(framesReceived),
    FBBroadcastKeyOrientation: @(self.currentOrientation),
    FBBroadcastKeyScreenWidth: @(self.screenWidth),
    FBBroadcastKeyScreenHeight: @(self.screenHeight),
  }];
  // ReplayKit delivery rate plus loopback backpressure, so a low consumer-side fps can be
  // attributed to delivery, a pipeline stage (see the per-pipeline counters) or the socket.
  payload[@"framesReceivedPerSec"] = @(FBExtRatePerSec((double)(framesReceived - self.previousFramesReceived), intervalSec));
  payload[@"socketOutstandingBytes"] = @(self.outstandingWriteBytes);

  NSMutableDictionary *pipelinesJson = [NSMutableDictionary dictionary];
  NSMutableDictionary *newTotals = [NSMutableDictionary dictionary];
  [self.pipelines enumerateKeysAndObjectsUsingBlock:^(NSNumber *sessionId, FBExtSessionPipeline *pipeline, BOOL *stop) {
    NSDictionary<NSString *, NSNumber *> *metrics = [pipeline metricsSnapshot];
    NSMutableDictionary *entry = [metrics mutableCopy];
    NSDictionary *previous = self.previousPipelineTotals[sessionId.stringValue];
    for (NSString *key in @[@"samplesIn", @"accepted", @"encoded", @"repeated"]) {
      double delta = metrics[key].doubleValue - [previous[key] doubleValue];
      entry[[key stringByAppendingString:@"PerSec"]] = @(FBExtRatePerSec(delta, intervalSec));
    }
    pipelinesJson[sessionId.stringValue] = entry;
    newTotals[sessionId.stringValue] = metrics;
  }];
  if (pipelinesJson.count > 0) {
    payload[@"pipelines"] = pipelinesJson;
  }
  self.previousPipelineTotals = newTotals;
  self.previousFramesReceived = framesReceived;
  self.lastHeartbeatAtMs = nowMs;

  NSData *message = FBBroadcastEncodeJSONMessage(FBBroadcastMessageTypeHeartbeat, 0, payload);
  if (nil != message) {
    [self sendProtocolMessage:message isDroppable:NO];
  }
}

#pragma mark - Incoming messages

- (void)handleMessageWithHeader:(FBBroadcastMessageHeader)header payload:(NSData *)payload
{
  switch (header.type) {
    case FBBroadcastMessageTypeSessionAdd: {
      NSDictionary *configuration = FBBroadcastParseJSONPayload(payload);
      if (nil == configuration) {
        FBExtLogError("Session %u: SESSION_ADD payload is not a JSON object", header.sessionId);
        return;
      }
      [self addSession:header.sessionId configuration:configuration];
      return;
    }
    case FBBroadcastMessageTypeSessionRemove:
      [self removeSession:header.sessionId];
      return;
    case FBBroadcastMessageTypeKeyframeRequest:
      [self.pipelines[@(header.sessionId)] requestKeyFrame];
      return;
    case FBBroadcastMessageTypeStopBroadcast:
      FBExtLogInfo("WDA requested the broadcast to stop");
      self.stopped = YES;
      [self.delegate broadcastClientDidRequestStop:self];
      return;
    default:
      FBExtLogError("Ignoring an unexpected message of type 0x%02x", header.type);
      return;
  }
}

- (void)addSession:(uint32_t)sessionId configuration:(NSDictionary<NSString *, id> *)configuration
{
  [self removeSession:sessionId];
  NSError *error;
  FBExtSessionPipeline *pipeline = [[FBExtSessionPipeline alloc] initWithSessionId:sessionId
                                                                     configuration:configuration
                                                                              sink:self
                                                                             error:&error];
  if (nil == pipeline) {
    FBExtLogError("Session %u: cannot create a pipeline: %{public}@", sessionId, error.description);
    NSData *message = FBBroadcastEncodeJSONMessage(FBBroadcastMessageTypeSessionError, sessionId, @{
      FBBroadcastKeyMessage: error.localizedDescription ?: @"Cannot create the session pipeline",
    });
    if (nil != message) {
      [self sendProtocolMessage:message isDroppable:NO];
    }
    return;
  }
  self.pipelines[@(sessionId)] = pipeline;
  self.activePipelines = self.pipelines;
  FBExtLogInfo("Session %u: pipeline created (%{public}@)", sessionId, configuration.description);
}

- (void)removeSession:(uint32_t)sessionId
{
  FBExtSessionPipeline *pipeline = self.pipelines[@(sessionId)];
  if (nil == pipeline) {
    return;
  }
  [pipeline teardown];
  [self.pipelines removeObjectForKey:@(sessionId)];
  self.activePipelines = self.pipelines;
  FBExtLogInfo("Session %u: pipeline removed", sessionId);
}

#pragma mark - <GCDAsyncSocketDelegate>

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
  FBExtLogInfo("Connected to WDA at %{public}@:%d", host, port);
  self.connected = YES;
  self.remainingConnectAttempts = CONNECT_ATTEMPTS;
  NSData *hello = FBBroadcastEncodeJSONMessage(FBBroadcastMessageTypeHello, 0, @{
    FBBroadcastKeyProtocolVersion: @(FBBroadcastProtocolVersion),
    FBBroadcastKeyOsVersion: NSProcessInfo.processInfo.operatingSystemVersionString,
  });
  if (nil != hello) {
    [self sendProtocolMessage:hello isDroppable:NO];
  }
  [self startHeartbeat];
  [sock readDataToLength:FBBroadcastHeaderLength withTimeout:-1 tag:TAG_HEADER];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (tag == TAG_HEADER) {
    FBBroadcastMessageHeader header;
    if (!FBBroadcastParseHeader(data, &header)) {
      FBExtLogError("Malformed control message header; disconnecting");
      [sock disconnect];
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

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  if (tag > 0 && self.outstandingWriteBytes >= (size_t)tag) {
    self.outstandingWriteBytes -= (size_t)tag;
  } else {
    self.outstandingWriteBytes = 0;
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)error
{
  if (sock != self.socket) {
    return;
  }
  self.connected = NO;
  self.outstandingWriteBytes = 0;
  [self stopHeartbeat];
  if (self.stopped) {
    return;
  }
  FBExtLogError("Disconnected from WDA: %{public}@", error.description ?: @"closed");
  [self scheduleReconnectOrGiveUp:error];
}

@end
