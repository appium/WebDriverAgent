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

// Textual import, not `@import Network;` - see the comment in FBTCPSocket.h.
#import <Network/Network.h>
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBScreenshot.h"
#import "FBImageProcessor.h"
#import "FBImageUtils.h"
#import "XCUIScreen.h"

static const NSUInteger MAX_FPS = 60;
static const NSTimeInterval FRAME_TIMEOUT = 1.;
// nw_connection_send buffers without backpressure, so a client that stops reading would retain
// every generated frame. Frames past this cap are dropped instead of queued.
static const NSUInteger MAX_PENDING_FRAMES_PER_CLIENT = 4;
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
@property (nonatomic, readonly) NSMutableArray<nw_connection_t> *listeningClients;
@property (nonatomic, readonly) FBImageProcessor *imageProcessor;
@property (nonatomic, readonly) long long mainScreenID;
@property (nonatomic, assign) NSUInteger consecutiveScreenshotFailures;
@property (atomic, assign) BOOL isStreaming;
@property (nonatomic, assign) NSUInteger sentFramesCount;
@property (nonatomic, assign) NSUInteger sentBytesCount;
@property (nonatomic, assign) NSUInteger droppedFramesCount;
// Frames submitted but not sent yet, per client. Guarded by @synchronized (self.listeningClients).
@property (nonatomic, readonly) NSMapTable<id, NSNumber *> *pendingFrameCounts;

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
    _pendingFrameCounts = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSMapTableObjectPointerPersonality | NSMapTableStrongMemory)
                                                valueOptions:(NSPointerFunctionsOptions)NSMapTableStrongMemory];
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
  NSUInteger framerate = FBNormalizedMjpegFramerate(FBConfiguration.sharedInstance.mjpegServerFramerate);
  uint64_t timerInterval = (uint64_t)(1.0 / (double)framerate * NSEC_PER_SEC);
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
  @synchronized (self.listeningClients) {
    if (0 == self.listeningClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  NSError *error;
  CGFloat compressionQuality = MAX(FBMinCompressionQuality,
                                   MIN(FBMaxCompressionQuality, (double)FBConfiguration.sharedInstance.mjpegServerScreenshotQuality / 100.0));
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

  CGFloat scalingFactor = FBConfiguration.sharedInstance.mjpegScalingFactor / 100.0;
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
    __weak typeof(self) weakSelf = self;
    for (nw_connection_t client in self.listeningClients) {
      NSUInteger pendingFrames = [self.pendingFrameCounts objectForKey:client].unsignedIntegerValue;
      if (pendingFrames >= MAX_PENDING_FRAMES_PER_CLIENT) {
        self.droppedFramesCount++;
        continue;
      }
      [self.pendingFrameCounts setObject:@(pendingFrames + 1) forKey:client];
      [self.socket writeData:chunk toClient:client completion:^(BOOL didSucceed) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (nil == strongSelf) {
          return;
        }
        @synchronized (strongSelf.listeningClients) {
          NSUInteger stillPending = [strongSelf.pendingFrameCounts objectForKey:client].unsignedIntegerValue;
          if (stillPending > 1) {
            [strongSelf.pendingFrameCounts setObject:@(stillPending - 1) forKey:client];
          } else {
            [strongSelf.pendingFrameCounts removeObjectForKey:client];
          }
        }
      }];
    }
    self.sentFramesCount++;
    self.sentBytesCount += chunk.length * clientCount;
    NSUInteger framerate = FBNormalizedMjpegFramerate(FBConfiguration.sharedInstance.mjpegServerFramerate);
    if (0 == self.sentFramesCount % framerate) {
      [FBLogger verboseLog:[NSString stringWithFormat:@"MJPEG stats: clients=%@ sentFrames=%@ sentBytes=%@ droppedFrames=%@",
                            @(clientCount),
                            @(self.sentFramesCount),
                            @(self.sentBytesCount),
                            @(self.droppedFramesCount)]];
    }
  }
}

- (void)didClientConnect:(nw_connection_t)newClient
{
  [FBLogger log:@"Got screenshots broadcast client connection"];
  // FBTCPSocket already schedules the receive that -client:didReceiveData: relies on below.
}

- (void)client:(nw_connection_t)client didReceiveData:(NSData *)data
{
  @synchronized (self.listeningClients) {
    if ([self.listeningClients containsObject:client]) {
      return;
    }
  }

  [FBLogger log:@"Starting screenshots broadcast for the client"];
  NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
  [self.socket writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] toClient:client];
  @synchronized (self.listeningClients) {
    [self.listeningClients addObject:client];
  }
}

- (void)didClientDisconnect:(nw_connection_t)client
{
  @synchronized (self.listeningClients) {
    [self.listeningClients removeObject:client];
    [self.pendingFrameCounts removeObjectForKey:client];
  }
  [FBLogger log:@"Disconnected a client from screenshots broadcast"];
}

- (void)stopStreaming
{
  self.isStreaming = NO;
  @synchronized (self.listeningClients) {
    NSArray<nw_connection_t> *clients = self.listeningClients.copy;
    [self.listeningClients removeAllObjects];
    [self.pendingFrameCounts removeAllObjects];
    for (nw_connection_t client in clients) {
      nw_connection_cancel(client);
    }
  }
}

- (void)dealloc
{
  [self stopStreaming];
  [FBLogger verboseLog:@"FBMjpegServer deallocated"];
}

@end
