/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMjpegServer.h"

#import <mach/mach_time.h>
@import UniformTypeIdentifiers;

#import "GCDAsyncSocket.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBScreenshot.h"
#import "FBImageProcessor.h"
#import "FBImageUtils.h"
#import "XCUIScreen.h"

static const NSUInteger MAX_FPS = 60;
static const NSTimeInterval FRAME_TIMEOUT = 1.;
static const NSTimeInterval FAILURE_BACKOFF_MIN = 1.0;
static const NSTimeInterval FAILURE_BACKOFF_MAX = 10.0;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";

static NSUInteger FBNormalizedMjpegFramerate(NSUInteger framerate)
{
  return (0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate;
}


@interface FBMjpegServer()

@property (nonatomic, readonly) dispatch_queue_t backgroundQueue;
@property (nonatomic, readonly) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, readonly) FBImageProcessor *imageProcessor;
@property (nonatomic, readonly) long long mainScreenID;
@property (nonatomic, assign) NSUInteger consecutiveScreenshotFailures;
@property (atomic, assign) BOOL isStreaming;
@property (nonatomic, assign) NSUInteger sentFramesCount;
@property (nonatomic, assign) NSUInteger sentBytesCount;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _consecutiveScreenshotFailures = 0;
    _isStreaming = YES;
    _sentFramesCount = 0;
    _sentBytesCount = 0;
    _listeningClients = [NSMutableArray array];
    _imageProcessor = [[FBImageProcessor alloc] init];
    _mainScreenID = [XCUIScreen.mainScreen displayID];
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
    __weak typeof(self) weakSelf = self;
    dispatch_async(_backgroundQueue, ^{
      [weakSelf streamScreenshot];
    });
  }
  return self;
}

- (void)scheduleNextScreenshotWithInterval:(uint64_t)timerInterval timeStarted:(uint64_t)timeStarted
{
  if (!self.isStreaming) {
    return;
  }
  uint64_t timeElapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted;
  int64_t nextTickDelta = (int64_t)timerInterval - (int64_t)timeElapsed;
  __weak typeof(self) weakSelf = self;
  if (nextTickDelta > 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nextTickDelta), self.backgroundQueue, ^{
      [weakSelf streamScreenshot];
    });
  } else {
    // Try to do our best to keep the FPS at a decent level
    dispatch_async(self.backgroundQueue, ^{
      [weakSelf streamScreenshot];
    });
  }
}

- (void)streamScreenshot
{
  if (!self.isStreaming) {
    return;
  }
  NSUInteger framerate = FBNormalizedMjpegFramerate(FBConfiguration.mjpegServerFramerate);
  uint64_t timerInterval = (uint64_t)(1.0 / framerate * NSEC_PER_SEC);
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
  @synchronized (self.listeningClients) {
    if (0 == self.listeningClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  NSError *error;
  CGFloat compressionQuality = MAX(FBMinCompressionQuality,
                                   MIN(FBMaxCompressionQuality, FBConfiguration.mjpegServerScreenshotQuality / 100.0));
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:self.mainScreenID
                                                           compressionQuality:compressionQuality
                                                                          uti:UTTypeJPEG
                                                                      timeout:FRAME_TIMEOUT
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    self.consecutiveScreenshotFailures++;
    NSTimeInterval backoffSeconds = MIN(FAILURE_BACKOFF_MAX,
                                        FAILURE_BACKOFF_MIN * (1 << MIN(self.consecutiveScreenshotFailures, 4)));
    uint64_t backoffInterval = (uint64_t)(backoffSeconds * NSEC_PER_SEC);
    [self scheduleNextScreenshotWithInterval:backoffInterval timeStarted:timeStarted];
    return;
  }

  self.consecutiveScreenshotFailures = 0;

  CGFloat scalingFactor = FBConfiguration.mjpegScalingFactor / 100.0;
  __weak typeof(self) weakSelf = self;
  [self.imageProcessor submitImageData:screenshotData
                         scalingFactor:scalingFactor
                     completionHandler:^(NSData * _Nonnull scaled) {
    [weakSelf sendScreenshot:scaled];
  }];

  [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
}

- (void)sendScreenshot:(NSData *)screenshotData {
  if (!self.isStreaming) {
    return;
  }
  NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpeg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
  NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [chunk appendData:screenshotData];
  [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  @synchronized (self.listeningClients) {
    if (!self.isStreaming || 0 == self.listeningClients.count) {
      return;
    }
    NSUInteger clientCount = self.listeningClients.count;
    for (GCDAsyncSocket *client in self.listeningClients) {
      // Slow clients should fail/close instead of buffering indefinitely.
      [client writeData:chunk withTimeout:FRAME_TIMEOUT tag:0];
    }
    self.sentFramesCount++;
    self.sentBytesCount += chunk.length * clientCount;
    NSUInteger framerate = FBNormalizedMjpegFramerate(FBConfiguration.mjpegServerFramerate);
    if (0 == self.sentFramesCount % framerate) {
      [FBLogger verboseLog:[NSString stringWithFormat:@"MJPEG stats: clients=%@ sentFrames=%@ sentBytes=%@",
                            @(clientCount),
                            @(self.sentFramesCount),
                            @(self.sentBytesCount)]];
    }
  }
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient
{
  [FBLogger logFmt:@"Got screenshots broadcast client connection at %@:%d", newClient.connectedHost, newClient.connectedPort];
  // Start broadcast only after there is any data from the client
  [newClient readDataWithTimeout:-1 tag:0];
}

- (void)didClientSendData:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    if ([self.listeningClients containsObject:client]) {
      return;
    }
  }

  [FBLogger logFmt:@"Starting screenshots broadcast for the client at %@:%d", client.connectedHost, client.connectedPort];
  NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
  [client writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
  @synchronized (self.listeningClients) {
    [self.listeningClients addObject:client];
  }
}

- (void)didClientDisconnect:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    [self.listeningClients removeObject:client];
  }
  [FBLogger log:@"Disconnected a client from screenshots broadcast"];
}

- (void)stopStreaming
{
  self.isStreaming = NO;
  @synchronized (self.listeningClients) {
    NSArray<GCDAsyncSocket *> *clients = self.listeningClients.copy;
    [self.listeningClients removeAllObjects];
    for (GCDAsyncSocket *client in clients) {
      [client disconnect];
    }
  }
}

- (void)dealloc
{
  [self stopStreaming];
  [FBLogger verboseLog:@"FBMjpegServer deallocated"];
}

@end
