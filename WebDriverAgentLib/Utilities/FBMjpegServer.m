/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

@import CocoaAsyncSocket;

#import "FBMjpegServer.h"

#import <mach/mach_time.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIScreen.h"
#import "FBImageIOScaler.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static const NSUInteger MAX_FPS = 60;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()

@property (nonatomic, readonly) dispatch_queue_t backgroundQueue;
@property (nonatomic, readonly) NSMutableArray<GCDAsyncSocket *> *activeClients;
@property (nonatomic, readonly) mach_timebase_info_data_t timebaseInfo;
@property (nonatomic, readonly) FBImageIOScaler *imageScaler;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _activeClients = [NSMutableArray array];
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
    mach_timebase_info(&_timebaseInfo);
    dispatch_async(_backgroundQueue, ^{
      [self streamScreenshot];
    });
    _imageScaler = [[FBImageIOScaler alloc] init];
  }
  return self;
}

- (void)scheduleNextScreenshotWithInterval:(uint64_t)timerInterval timeStarted:(uint64_t)timeStarted
{
  uint64_t timeElapsed = mach_absolute_time() - timeStarted;
  int64_t nextTickDelta = timerInterval - timeElapsed * self.timebaseInfo.numer / self.timebaseInfo.denom;
  if (nextTickDelta > 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nextTickDelta), self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  } else {
    // Try to do our best to keep the FPS at a decent level
    dispatch_async(self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  }
}

- (void)streamScreenshot
{
  if (![self.class canStreamScreenshots]) {
    [FBLogger log:@"MJPEG server cannot start because the current iOS version is not supported"];
    return;
  }

  NSUInteger framerate = FBConfiguration.mjpegServerFramerate;
  uint64_t timerInterval = (uint64_t)(1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate) * NSEC_PER_SEC);
  uint64_t timeStarted = mach_absolute_time();
  @synchronized (self.activeClients) {
    if (0 == self.activeClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  __block NSData *screenshotData = nil;

  CGFloat scalingFactor = [FBConfiguration mjpegScalingFactor] / 100.0f;
  BOOL usesScaling = fabs(1.0 - scalingFactor) > DBL_EPSILON;

  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;

  // If scaling is applied we perform another JPEG compression after scaling
  // To get the desired compressionQuality we need to do a lossless compression here
  if (usesScaling) {
    compressionQuality = 1.0;
  }
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                       withRect:CGRectNull
                                            uti:(__bridge id)kUTTypeJPEG
                             compressionQuality:compressionQuality
                                      withReply:^(NSData *data, NSError *error) {
    if (error != nil) {
      [FBLogger logFmt:@"Error taking screenshot: %@", [error description]];
    }
    screenshotData = data;
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  if (nil == screenshotData) {
    [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
    return;
  }

  if (usesScaling) {
    [self.imageScaler submitImage:screenshotData
                    scalingFactor:scalingFactor
               compressionQuality:compressionQuality
                completionHandler:^(NSData * _Nonnull scaled) {
                  [self sendScreenshot:scaled];
                }];
  } else {
    [self sendScreenshot:screenshotData];
  }

  [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
}

- (void)sendScreenshot:(NSData *)screenshotData {
  NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
  NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [chunk appendData:screenshotData];
  [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  @synchronized (self.activeClients) {
    for (GCDAsyncSocket *client in self.activeClients) {
      [client writeData:chunk withTimeout:-1 tag:0];
    }
  }
}

+ (BOOL)canStreamScreenshots
{
  static dispatch_once_t onceCanStream;
  static BOOL result;
  dispatch_once(&onceCanStream, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient activeClients:(NSArray<GCDAsyncSocket *> *)activeClients
{
  NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
  [newClient writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
  @synchronized (self.activeClients) {
    [self.activeClients removeAllObjects];
    [self.activeClients addObjectsFromArray:activeClients];
  }
}

- (void)didClientDisconnect:(NSArray<GCDAsyncSocket *> *)activeClients
{
  @synchronized (self.activeClients) {
    [self.activeClients removeAllObjects];
    [self.activeClients addObjectsFromArray:activeClients];
  }
}

@end
