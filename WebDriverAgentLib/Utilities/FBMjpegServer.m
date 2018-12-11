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

#import <MobileCoreServices/MobileCoreServices.h>
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIScreen.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static const NSUInteger MAX_FPS = 60;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()

@property (nonatomic) NSTimer *mainTimer;
@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *activeClients;
@property (nonatomic) NSUInteger currentFramerate;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _activeClients = [NSMutableArray array];
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
    if (![self.class canStreamScreenshots]) {
      [FBLogger log:@"MJPEG server cannot start because the current iOS version is not supported"];
      return self;
    }
    [self resetTimer:FBConfiguration.mjpegServerFramerate];
  }
  return self;
}

- (void)resetTimer:(NSUInteger)framerate
{
  if (self.mainTimer && self.mainTimer.valid) {
    [self.mainTimer invalidate];
  }
  self.currentFramerate = framerate;
  NSTimeInterval timerInterval = 1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate);
  self.mainTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                   repeats:YES
                                                     block:^(NSTimer * _Nonnull timer) {
                                                       if (self.currentFramerate == FBConfiguration.mjpegServerFramerate) {
                                                         [self streamScreenshot];
                                                       } else {
                                                         [self resetTimer:FBConfiguration.mjpegServerFramerate];
                                                       }
                                                     }];
}

- (void)streamScreenshot
{
  @synchronized (self.activeClients) {
    if (0 == self.activeClients.count) {
      return;
    }
  }

  __block NSData *screenshotData = nil;
  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                       withRect:CGRectNull
                                            uti:(__bridge id)kUTTypeJPEG
                             compressionQuality:compressionQuality
                                      withReply:^(NSData *data, NSError *error) {
      screenshotData = data;
      dispatch_semaphore_signal(sem);
                                      }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  if (nil == screenshotData) {
    return;
  }

  dispatch_async(self.backgroundQueue, ^{
    NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
    NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [chunk appendData:screenshotData];
    [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    @synchronized (self.activeClients) {
      for (GCDAsyncSocket *client in self.activeClients) {
        [client writeData:chunk withTimeout:-1 tag:0];
      }
    }
  });
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
  if (![self.class canStreamScreenshots]) {
    return;
  }

  dispatch_async(self.backgroundQueue, ^{
    NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
    [newClient writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
  });

  @synchronized (self.activeClients) {
    [self.activeClients removeAllObjects];
    [self.activeClients addObjectsFromArray:activeClients];
  }
}

- (void)didClientDisconnect:(NSArray<GCDAsyncSocket *> *)activeClients
{
  if (![self.class canStreamScreenshots]) {
    return;
  }

  @synchronized (self.activeClients) {
    [self.activeClients removeAllObjects];
    [self.activeClients addObjectsFromArray:activeClients];
  }
}

@end
