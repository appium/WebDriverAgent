/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAudioStreamSession.h"

#import <errno.h>
#import <mach/mach_time.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <sys/socket.h>

#import "GCDAsyncSocket.h"
#import "FBBroadcastProtocol.h"
#import "FBLogger.h"
#import "FBScrcpyPacket.h"
#import "FBTCPSocket.h"

static const NSTimeInterval PACKET_TIMEOUT = 1.0;
static const NSUInteger FBAudioStreamSampleRate = 48000;

@implementation FBAudioCaptureConfiguration
@end


@interface FBAudioStreamSession () <FBTCPSocketDelegate>

@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, nullable) FBTCPSocket *broadcaster;
@property (atomic, getter=isActive) BOOL active;
/** The OpusHead describing the stream; the extension's real one replaces the synthesized fallback. */
@property (atomic, copy) NSData *currentOpusHead;
/** The OpusHead most recently broadcast as a scrcpy config packet (for change detection). */
@property (nonatomic, nullable, copy) NSData *lastSentOpusHead;
@property (atomic) BOOL streaming;
@property (atomic) uint64_t packetsReceived;
@property (atomic) uint64_t lastPacketAtMs;
@property (atomic, nullable, copy) NSString *lastError;

@end


@implementation FBAudioStreamSession

- (instancetype)initWithIdentifier:(NSUInteger)identifier
                     configuration:(FBAudioCaptureConfiguration *)configuration
{
  if ((self = [super init])) {
    _identifier = identifier;
    _configuration = configuration;
    _listeningClients = [NSMutableArray array];
    _active = NO;
    _streaming = NO;
    // A synthesized header (pre-skip 0) so scrcpy-framing clients always receive a config packet
    // on connect; the extension's AUDIO_PARAMS replaces it with the encoder's real values.
    _currentOpusHead = FBBroadcastCreateOpusHead((uint8_t)configuration.channels,
                                                 0,
                                                 (uint32_t)FBAudioStreamSampleRate);
  }
  return self;
}

- (BOOL)startWithError:(NSError **)error
{
  self.broadcaster = [[FBTCPSocket alloc] initWithPort:self.configuration.port];
  self.broadcaster.delegate = self;
  if (![self.broadcaster startWithError:error]) {
    self.broadcaster = nil;
    return NO;
  }
  self.active = YES;
  return YES;
}

- (void)stop
{
  @synchronized (self) {
    self.active = NO;
    self.streaming = NO;
    if (nil != self.broadcaster) {
      self.broadcaster.delegate = nil;
      [self.broadcaster stop];
      self.broadcaster = nil;
    }
    @synchronized (self.listeningClients) {
      [self.listeningClients removeAllObjects];
    }
  }
}

- (BOOL)hasClients
{
  @synchronized (self.listeningClients) {
    return self.listeningClients.count > 0;
  }
}

#pragma mark - Broadcast (ReplayKit) source

- (void)ingestBroadcastOpusHead:(NSData *)opusHead
{
  if (opusHead.length == 0) {
    return;
  }
  self.currentOpusHead = opusHead;
  self.lastError = nil;
}

- (void)ingestBroadcastPacket:(NSData *)opusPacket ptsUs:(uint64_t)ptsUs
{
  if (!self.isActive || opusPacket.length == 0) {
    return;
  }
  self.streaming = YES;
  self.packetsReceived += 1;
  self.lastPacketAtMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;

  if (self.configuration.framing == FBAudioFramingScrcpy) {
    // Re-broadcast the codec configuration whenever it changed. Like scrcpy itself, config
    // packets carry only the config flag (zero pts) and data packets carry only the pts.
    NSData *opusHead = self.currentOpusHead;
    @synchronized (self) {
      if (nil == self.lastSentOpusHead || ![opusHead isEqualToData:(NSData *)self.lastSentOpusHead]) {
        self.lastSentOpusHead = opusHead;
        [self broadcastData:FBScrcpyPacketCreate(opusHead, FBScrcpyFlagConfig, 0)];
      }
    }
    [self broadcastData:FBScrcpyPacketCreate(opusPacket, 0, ptsUs)];
    return;
  }
  [self broadcastData:opusPacket];
}

- (void)detachBroadcastSource
{
  self.streaming = NO;
}

- (void)markBroadcastError:(NSString *)message
{
  self.streaming = NO;
  self.lastError = message;
}

- (void)broadcastData:(NSData *)data
{
  if (data.length == 0) {
    return;
  }
  @synchronized (self.listeningClients) {
    for (GCDAsyncSocket *client in self.listeningClients) {
      // Slow clients should fail/close instead of buffering indefinitely.
      [client writeData:data withTimeout:PACKET_TIMEOUT tag:0];
    }
  }
}

#pragma mark - <FBTCPSocketDelegate>

- (void)didClientConnect:(GCDAsyncSocket *)newClient
{
  [FBLogger logFmt:@"Audio capture session %@: client connected at %@:%d",
   @(self.identifier), newClient.connectedHost, newClient.connectedPort];
  // Disable Nagle's algorithm so small Opus packets are sent immediately, keeping latency low.
  [self.class enableNoDelayForClient:newClient];
  @synchronized (self.listeningClients) {
    if (![self.listeningClients containsObject:newClient]) {
      [self.listeningClients addObject:newClient];
    }
  }
  // Hand the codec configuration to the new client so it can start decoding immediately.
  // lastSentOpusHead is deliberately not updated: it tracks what was broadcast to the whole
  // client set, and marking it sent here would skip the changed-config broadcast that earlier
  // clients still need (the new client just receives the same config twice, which is harmless).
  if (self.configuration.framing == FBAudioFramingScrcpy) {
    [newClient writeData:FBScrcpyPacketCreate(self.currentOpusHead, FBScrcpyFlagConfig, 0)
             withTimeout:PACKET_TIMEOUT
                     tag:0];
  }
  // Keep reading (and discarding) any client bytes so disconnects are detected promptly.
  [newClient readDataWithTimeout:-1 tag:0];
}

- (void)didClientSendData:(GCDAsyncSocket *)client
{
  // The stream is push-only; client payloads are ignored. Keep the read loop alive.
  [client readDataWithTimeout:-1 tag:0];
}

- (void)didClientDisconnect:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    [self.listeningClients removeObject:client];
  }
  [FBLogger logFmt:@"Audio capture session %@: client disconnected", @(self.identifier)];
}

#pragma mark - Status

- (NSDictionary *)toDictionary
{
  NSUInteger clientCount;
  @synchronized (self.listeningClients) {
    clientCount = self.listeningClients.count;
  }
  uint64_t lastPacketAtMs = self.lastPacketAtMs;
  NSString *lastError = self.lastError;
  return @{
    @"id": @(self.identifier),
    @"codec": FBBroadcastCodecOpus,
    @"framing": self.configuration.framing == FBAudioFramingScrcpy ? @"scrcpy" : @"raw",
    @"sampleRate": @(FBAudioStreamSampleRate),
    @"channels": @(self.configuration.channels),
    @"bitrate": @(self.configuration.bitrate),
    @"port": @(self.configuration.port),
    @"clients": @(clientCount),
    @"streaming": @(self.streaming),
    @"source": self.streaming ? @"replaykit" : @"none",
    @"packetsReceived": @(self.packetsReceived),
    @"lastPacketAtMs": lastPacketAtMs > 0 ? @(lastPacketAtMs) : NSNull.null,
    @"lastError": lastError ?: NSNull.null,
  };
}

+ (void)enableNoDelayForClient:(GCDAsyncSocket *)client
{
  [client performBlock:^{
    int fd = client.socketFD;
    if (fd < 0) {
      return;
    }
    int flag = 1;
    if (0 != setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag))) {
      [FBLogger logFmt:@"Cannot enable TCP_NODELAY on the audio capture client socket (errno %d)", errno];
    }
  }];
}

@end
