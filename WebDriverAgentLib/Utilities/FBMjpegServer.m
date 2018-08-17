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
#import "FBLogger.h"
#import "FBMathUtils.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"

static const NSUInteger FPS = 10;
static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static const double SCREENSHOT_QUALITY = 0.25;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()

@property (nonatomic, nullable) NSTimer *mainTimer;
@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *activeClients;
@property (nonatomic, nullable) NSValue *screenRect;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _activeClients = [NSMutableArray array];
    _screenRect = nil;
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
    if (![self.class canStreamScreenshots]) {
      [FBLogger log:@"MJPEG server cannot start because the current iOS version is not supoprted"];
      return self;
    }
    _mainTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FPS repeats:YES block:^(NSTimer * _Nonnull timer) {
      @synchronized (self.activeClients) {
        if (0 == self.activeClients.count) {
          return;
        }
      }

      @synchronized(self.screenRect) {
        if (nil == self.screenRect || CGRectIsEmpty(self.screenRect.CGRectValue)) {
          return;
        }

        __block NSData *screenshotData = nil;
        id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [proxy _XCT_setAXTimeout:SCREENSHOT_TIMEOUT reply:^(int res) {
          [proxy _XCT_requestScreenshotOfScreenWithID:1
                                             withRect:self.screenRect.CGRectValue
                                                  uti:nil
                                   compressionQuality:SCREENSHOT_QUALITY
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
          NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
          NSString *chunkTail = @"\r\n\r\n";
          NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
          [chunk appendData:screenshotData];
          [chunk appendData:(id)[chunkTail dataUsingEncoding:NSUTF8StringEncoding]];
          @synchronized (self.activeClients) {
            for (GCDAsyncSocket *client in self.activeClients) {
              [client writeData:chunk.copy withTimeout:-1 tag:0];
            }
          }
        });
      }
    }];
  }
  return self;
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
      [FBLogger logFmt:@"Cannot retrieve the actual screen size. Will continue using the current value: %@", self.screenRect];
      return;
    }
    CGSize screenSize = FBAdjustDimensionsForApplication(appFrame.size, systemApp.interfaceOrientation);
    @synchronized (self.screenRect) {
      self.screenRect = [NSValue valueWithCGRect:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    }
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
