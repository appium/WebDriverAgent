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

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBMathUtils.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static const NSUInteger MAX_FPS = 60;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()

@property (nonatomic) NSTimer *mainTimer;
@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *activeClients;
@property (nonatomic) CGRect screenRect;
@property (nonatomic) NSUInteger currentFramerate;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _activeClients = [NSMutableArray array];
    _screenRect = CGRectZero;
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

+ (BOOL)isJPEGData:(nullable NSData *)data
{
  static const NSUInteger magicLen = 2;
  if (nil == data || [data length] < magicLen) {
    return NO;
  }

  static NSData* magicStartData = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    static uint8_t magic[] = { 0xff, 0xd8 };
    magicStartData = [NSData dataWithBytesNoCopy:(void*)magic length:magicLen freeWhenDone:NO];
  });

  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wassign-enum"
  NSRange range = [data rangeOfData:magicStartData options:kNilOptions range:NSMakeRange(0, magicLen)];
  #pragma clang diagnostic pop
  return range.location != NSNotFound;
}

- (void)streamScreenshot
{
  @synchronized (self.activeClients) {
    if (0 == self.activeClients.count) {
      return;
    }
  }

  if (CGRectIsEmpty(self.screenRect)) {
    return;
  }
  __block NSData *screenshotData = nil;
  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_setAXTimeout:SCREENSHOT_TIMEOUT reply:^(int res) {
    [proxy _XCT_requestScreenshotOfScreenWithID:1
                                       withRect:self.screenRect
                                            uti:nil
                             compressionQuality:compressionQuality
                                      withReply:^(NSData *data, NSError *error) {
      screenshotData = data;
      dispatch_semaphore_signal(sem);
    }];
  }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  if (nil == screenshotData) {
    return;
  }

  dispatch_async(self.backgroundQueue, ^{
    NSData *jpegData;
    // Sometimes XCTest might still return PNG screenshots
    if ([self.class isJPEGData:screenshotData]) {
      jpegData = screenshotData;
    } else {
      UIImage *image = [UIImage imageWithData:screenshotData];
      if (nil == image) {
        return;
      }
      jpegData = UIImageJPEGRepresentation(image, compressionQuality);
      if (nil == jpegData) {
        return;
      }
    }
    NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(jpegData.length)];
    NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [chunk appendData:jpegData];
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

- (void)refreshScreenRect
{
  if (![self.class canStreamScreenshots]) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    FBApplication *systemApp = FBApplication.fb_systemApplication;
    CGRect appFrame = [systemApp frame];
    if (CGRectIsEmpty(appFrame)) {
      [FBLogger logFmt:@"Cannot retrieve the actual screen size. Will continue using the current value: %@", [NSValue valueWithCGRect:self.screenRect]];
      return;
    }
    CGSize screenSize = FBAdjustDimensionsForApplication(appFrame.size, systemApp.interfaceOrientation);
    self.screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
  });
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient activeClients:(NSArray<GCDAsyncSocket *> *)activeClients
{
  if (![self.class canStreamScreenshots]) {
    return;
  }

  [self refreshScreenRect];

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
