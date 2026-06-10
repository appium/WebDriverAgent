/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBVideoStreamSession.h"

#import <errno.h>
#import <mach/mach_time.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <sys/socket.h>

#import "GCDAsyncSocket.h"
#import "FBLogger.h"
#import "FBPixelBufferConverter.h"
#import "FBTCPSocket.h"

static const NSTimeInterval FRAME_TIMEOUT = 1.0;

// scrcpy packet flags packed into the top two bits of the 8-byte presentation timestamp field.
static const uint64_t FBScrcpyFlagConfig   = (uint64_t)1 << 63;
static const uint64_t FBScrcpyFlagKeyFrame = (uint64_t)1 << 62;
static const uint64_t FBScrcpyPtsMask      = ~((uint64_t)3 << 62);

@implementation FBScreenCaptureConfiguration
@end


@interface FBVideoStreamSession () <FBTCPSocketDelegate, FBVideoEncoderDelegate>

@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, nullable) FBVideoEncoder *encoder;
@property (nonatomic, nullable) FBPixelBufferConverter *converter;
@property (nonatomic, nullable) FBTCPSocket *broadcaster;
@property (nonatomic) uint64_t lastPresentationTimeMs;
@property (nonatomic) uint64_t lastEncodeTimeMs;
/** The parameter sets most recently broadcast as a scrcpy config packet (for change detection). */
@property (nonatomic, nullable, copy) NSData *lastSentParameterSets;
@property (atomic, getter=isActive) BOOL active;
@property (atomic, readwrite) FBVideoStreamSource activeSource;
/** The parameter sets most recently received from the broadcast extension. */
@property (atomic, nullable, copy) NSData *broadcastParameterSets;

@end


@implementation FBVideoStreamSession

- (instancetype)initWithIdentifier:(NSUInteger)identifier
                     configuration:(FBScreenCaptureConfiguration *)configuration
{
  if ((self = [super init])) {
    _identifier = identifier;
    _configuration = configuration;
    _listeningClients = [NSMutableArray array];
    _active = NO;
    _activeSource = FBVideoStreamSourceScreenshot;
  }
  return self;
}

- (BOOL)startWithError:(NSError **)error
{
  // Bind the broadcast socket first so that a port conflict fails cheaply.
  self.broadcaster = [[FBTCPSocket alloc] initWithPort:self.configuration.port];
  self.broadcaster.delegate = self;
  if (![self.broadcaster startWithError:error]) {
    self.broadcaster = nil;
    return NO;
  }

  self.converter = [[FBPixelBufferConverter alloc] initWithWidth:self.configuration.width
                                                          height:self.configuration.height];
  FBVideoEncoder *encoder = [[FBVideoEncoder alloc] initWithCodec:self.configuration.codec
                                                           width:self.configuration.width
                                                          height:self.configuration.height
                                                         bitrate:self.configuration.bitrate
                                                             fps:self.configuration.fps
                                                           error:error];
  if (nil == encoder) {
    [self stop];
    return NO;
  }
  encoder.delegate = self;
  self.encoder = encoder;
  self.active = YES;
  return YES;
}

- (void)stop
{
  @synchronized (self) {
    self.active = NO;
    if (nil != self.broadcaster) {
      self.broadcaster.delegate = nil;
      [self.broadcaster stop];
      self.broadcaster = nil;
    }
    @synchronized (self.listeningClients) {
      [self.listeningClients removeAllObjects];
    }
    if (nil != self.encoder) {
      self.encoder.delegate = nil;
      [self.encoder stop];
      self.encoder = nil;
    }
    self.converter = nil;
  }
}

- (BOOL)hasClients
{
  @synchronized (self.listeningClients) {
    return self.listeningClients.count > 0;
  }
}

- (void)requestKeyFrame
{
  // While the broadcast extension feeds this session the local encoder is idle, so the request
  // must reach the extension's encoder instead.
  if (self.activeSource == FBVideoStreamSourceBroadcast) {
    void (^onKeyFrameNeeded)(NSUInteger) = self.onBroadcastKeyFrameNeeded;
    if (nil != onKeyFrameNeeded) {
      onKeyFrameNeeded(self.identifier);
      return;
    }
  }
  @synchronized (self) {
    [self.encoder requestKeyFrame];
  }
}

- (BOOL)requiresLocalFrames
{
  return self.isActive && self.activeSource == FBVideoStreamSourceScreenshot && [self hasClients];
}

- (void)maybeEncodeCGImage:(CGImageRef)image atTimeMs:(uint64_t)nowMs
{
  if (self.activeSource == FBVideoStreamSourceBroadcast) {
    return;
  }
  @synchronized (self) {
    if (!self.isActive || nil == self.encoder || ![self hasClients]) {
      return;
    }
    // Respect this session's framerate even though the shared loop may tick faster
    // (it ticks at the fastest session's rate).
    uint64_t minIntervalMs = self.configuration.fps > 0 ? (uint64_t)(1000 / self.configuration.fps) : 0;
    if (minIntervalMs > 1 && nowMs - self.lastEncodeTimeMs < minIntervalMs - 1) {
      return;
    }
    self.lastEncodeTimeMs = nowMs;

    NSError *error;
    CVPixelBufferRef pixelBuffer = [self.converter copyPixelBufferFromCGImage:image error:&error];
    if (NULL == pixelBuffer) {
      [FBLogger logFmt:@"Screen capture session %@: cannot build a pixel buffer: %@", @(self.identifier), error.description];
      return;
    }
    if (![self.encoder encodePixelBuffer:pixelBuffer presentationTimeMs:[self nextPresentationTimeMs] error:&error]) {
      [FBLogger logFmt:@"Screen capture session %@: cannot encode a frame: %@", @(self.identifier), error.description];
    }
    CVPixelBufferRelease(pixelBuffer);
  }
}

- (uint64_t)nextPresentationTimeMs
{
  uint64_t candidate = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
  if (candidate <= self.lastPresentationTimeMs) {
    candidate = self.lastPresentationTimeMs + 1;
  }
  self.lastPresentationTimeMs = candidate;
  return candidate;
}

#pragma mark - Broadcast (ReplayKit) source

- (void)ingestBroadcastParameterSets:(NSData *)parameterSets
{
  if (parameterSets.length > 0) {
    self.broadcastParameterSets = parameterSets;
  }
}

- (void)ingestBroadcastFrame:(NSData *)annexBPictureData isKeyFrame:(BOOL)isKeyFrame
{
  if (!self.isActive || annexBPictureData.length == 0) {
    return;
  }
  uint64_t presentationTimeUs;
  @synchronized (self) {
    if (self.activeSource == FBVideoStreamSourceScreenshot) {
      // Only take over at an IDR with parameter sets available, so connected clients can
      // resync at the source switch without reconnecting.
      if (!isKeyFrame || nil == self.broadcastParameterSets) {
        return;
      }
      self.activeSource = FBVideoStreamSourceBroadcast;
      // Force a fresh scrcpy config packet for the new elementary stream.
      self.lastSentParameterSets = nil;
      [FBLogger logFmt:@"Screen capture session %@: switched to the ReplayKit broadcast source", @(self.identifier)];
    }
    // Re-stamp with the session's own monotonic clock so one time base survives source switches;
    // the extension's timestamp is intentionally ignored.
    presentationTimeUs = [self nextPresentationTimeMs] * 1000;
  }
  [self emitEncodedPicture:annexBPictureData
                isKeyFrame:isKeyFrame
        presentationTimeUs:presentationTimeUs
             parameterSets:self.broadcastParameterSets];
}

- (void)detachBroadcastSourceAndForceKeyFrame
{
  @synchronized (self) {
    if (self.activeSource != FBVideoStreamSourceBroadcast) {
      return;
    }
    self.activeSource = FBVideoStreamSourceScreenshot;
    self.broadcastParameterSets = nil;
    // Force a fresh config packet and an IDR from the local encoder so clients resync.
    self.lastSentParameterSets = nil;
    [self.encoder requestKeyFrame];
  }
  [FBLogger logFmt:@"Screen capture session %@: reverted to the screenshot source", @(self.identifier)];
}

/** The parameter sets of whichever source currently feeds this session. */
- (nullable NSData *)currentParameterSets
{
  return self.activeSource == FBVideoStreamSourceBroadcast
    ? self.broadcastParameterSets
    : self.encoder.parameterSetAnnexB;
}

#pragma mark - <FBVideoEncoderDelegate>

- (void)videoEncoder:(FBVideoEncoder *)encoder
       didEncodeFrame:(NSData *)annexBPictureData
           isKeyFrame:(BOOL)isKeyFrame
   presentationTimeUs:(uint64_t)presentationTimeUs
{
  // While the broadcast source is active the local encoder's (at most one in-flight) output is
  // discarded; clients resync at the broadcast IDR that triggered the switch.
  if (self.activeSource == FBVideoStreamSourceBroadcast) {
    return;
  }
  [self emitEncodedPicture:annexBPictureData
                isKeyFrame:isKeyFrame
        presentationTimeUs:presentationTimeUs
             parameterSets:encoder.parameterSetAnnexB];
}

- (void)emitEncodedPicture:(NSData *)annexBPictureData
                isKeyFrame:(BOOL)isKeyFrame
        presentationTimeUs:(uint64_t)presentationTimeUs
             parameterSets:(nullable NSData *)parameterSets
{
  if (annexBPictureData.length == 0) {
    return;
  }

  if (self.configuration.framing == FBVideoFramingScrcpy) {
    // The consumer caches config packets and prepends them to key frames itself, so the key-frame
    // packet must carry picture data only. Emit a separate config packet whenever the parameter
    // sets change.
    if (isKeyFrame) {
      if (parameterSets.length > 0 && ![parameterSets isEqualToData:self.lastSentParameterSets]) {
        self.lastSentParameterSets = parameterSets;
        [self broadcastData:[self.class scrcpyPacketWithPayload:parameterSets
                                                          flags:FBScrcpyFlagConfig
                                             presentationTimeUs:presentationTimeUs]];
      }
    }
    uint64_t flags = isKeyFrame ? FBScrcpyFlagKeyFrame : 0;
    [self broadcastData:[self.class scrcpyPacketWithPayload:annexBPictureData
                                                      flags:flags
                                         presentationTimeUs:presentationTimeUs]];
    return;
  }

  // Annex-B mode: prepend the parameter sets to key frames so each IDR is independently decodable.
  if (isKeyFrame) {
    if (parameterSets.length > 0) {
      NSMutableData *keyFrame = [NSMutableData dataWithCapacity:parameterSets.length + annexBPictureData.length];
      [keyFrame appendData:parameterSets];
      [keyFrame appendData:annexBPictureData];
      [self broadcastData:keyFrame];
      return;
    }
  }
  [self broadcastData:annexBPictureData];
}

- (void)broadcastData:(NSData *)data
{
  if (data.length == 0) {
    return;
  }
  @synchronized (self.listeningClients) {
    for (GCDAsyncSocket *client in self.listeningClients) {
      // Slow clients should fail/close instead of buffering indefinitely.
      [client writeData:data withTimeout:FRAME_TIMEOUT tag:0];
    }
  }
}

+ (NSData *)scrcpyPacketWithPayload:(NSData *)payload
                              flags:(uint64_t)flags
                 presentationTimeUs:(uint64_t)presentationTimeUs
{
  uint64_t ptsAndFlags = flags | (presentationTimeUs & FBScrcpyPtsMask);
  uint8_t header[12];
  uint64_t bigPtsAndFlags = CFSwapInt64HostToBig(ptsAndFlags);
  memcpy(header, &bigPtsAndFlags, sizeof(bigPtsAndFlags));
  uint32_t bigSize = CFSwapInt32HostToBig((uint32_t)payload.length);
  memcpy(header + sizeof(bigPtsAndFlags), &bigSize, sizeof(bigSize));

  NSMutableData *packet = [NSMutableData dataWithCapacity:sizeof(header) + payload.length];
  [packet appendBytes:header length:sizeof(header)];
  [packet appendData:payload];
  return packet;
}

#pragma mark - <FBTCPSocketDelegate>

- (void)didClientConnect:(GCDAsyncSocket *)newClient
{
  [FBLogger logFmt:@"Screen capture session %@: client connected at %@:%d",
   @(self.identifier), newClient.connectedHost, newClient.connectedPort];
  // Disable Nagle's algorithm so small NAL units are sent immediately, keeping latency low.
  [self.class enableNoDelayForClient:newClient];
  @synchronized (self.listeningClients) {
    if (![self.listeningClients containsObject:newClient]) {
      [self.listeningClients addObject:newClient];
    }
  }
  // Hand the latest parameter sets to the new client and force a key frame so it can start
  // decoding immediately. In scrcpy mode the parameter sets are wrapped as a config packet.
  NSData *parameterSets = [self currentParameterSets];
  if (parameterSets.length > 0) {
    NSData *payload = self.configuration.framing == FBVideoFramingScrcpy
      ? [self.class scrcpyPacketWithPayload:parameterSets flags:FBScrcpyFlagConfig presentationTimeUs:0]
      : parameterSets;
    [newClient writeData:payload withTimeout:FRAME_TIMEOUT tag:0];
  }
  [self requestKeyFrame];
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
  [FBLogger logFmt:@"Screen capture session %@: client disconnected", @(self.identifier)];
}

#pragma mark - Status

- (NSDictionary *)toDictionary
{
  NSUInteger clientCount;
  @synchronized (self.listeningClients) {
    clientCount = self.listeningClients.count;
  }
  return @{
    @"id": @(self.identifier),
    @"codec": self.configuration.codec == FBVideoCodecH265 ? @"h265" : @"h264",
    @"framing": self.configuration.framing == FBVideoFramingScrcpy ? @"scrcpy" : @"annexb",
    @"width": @(self.configuration.width),
    @"height": @(self.configuration.height),
    @"fps": @(self.configuration.fps),
    @"bitrate": @(self.configuration.bitrate),
    @"port": @(self.configuration.port),
    @"clients": @(clientCount),
    @"source": self.activeSource == FBVideoStreamSourceBroadcast ? @"replaykit" : @"screenshot",
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
      [FBLogger logFmt:@"Cannot enable TCP_NODELAY on the screen capture client socket (errno %d)", errno];
    }
  }];
}

@end
