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
  @synchronized (self) {
    [self.encoder requestKeyFrame];
  }
}

- (void)maybeEncodeCGImage:(CGImageRef)image atTimeMs:(uint64_t)nowMs
{
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

#pragma mark - <FBVideoEncoderDelegate>

- (void)videoEncoder:(FBVideoEncoder *)encoder
       didEncodeFrame:(NSData *)annexBPictureData
           isKeyFrame:(BOOL)isKeyFrame
   presentationTimeUs:(uint64_t)presentationTimeUs
{
  if (annexBPictureData.length == 0) {
    return;
  }

  if (self.configuration.framing == FBVideoFramingScrcpy) {
    // The consumer caches config packets and prepends them to key frames itself, so the key-frame
    // packet must carry picture data only. Emit a separate config packet whenever the parameter
    // sets change.
    if (isKeyFrame) {
      NSData *parameterSets = encoder.parameterSetAnnexB;
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
    NSData *parameterSets = encoder.parameterSetAnnexB;
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
  NSData *parameterSets = self.encoder.parameterSetAnnexB;
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
