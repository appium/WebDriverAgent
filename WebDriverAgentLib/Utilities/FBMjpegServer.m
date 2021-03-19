/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBMjpegServer.h"

#import <mach/mach_time.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "GCDAsyncSocket.h"
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBScreenshot.h"
#import "FBImageIOScaler.h"
#import "XCUIScreen.h"

static const NSUInteger MAX_FPS = 60;
static const NSTimeInterval FRAME_TIMEOUT = 1.;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()

@property (nonatomic, readonly) dispatch_queue_t backgroundQueue;
@property (nonatomic, readonly) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, readonly) mach_timebase_info_data_t timebaseInfo;
@property (nonatomic, readonly) FBImageIOScaler *imageScaler;
@property (nonatomic, readonly) unsigned int mainScreenID;

@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _listeningClients = [NSMutableArray array];
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
    mach_timebase_info(&_timebaseInfo);
    dispatch_async(_backgroundQueue, ^{
      [self streamScreenshot];
    });
    _imageScaler = [[FBImageIOScaler alloc] init];
    _mainScreenID = [XCUIScreen.mainScreen displayID];
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
  @synchronized (self.listeningClients) {
    if (0 == self.listeningClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  CGFloat scalingFactor = [FBConfiguration mjpegScalingFactor] / 100.0f;
  BOOL usesScaling = fabs(FBMaxScalingFactor - scalingFactor) > DBL_EPSILON;
  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  // If scaling is applied we perform another JPEG compression after scaling
  // To get the desired compressionQuality we need to do a lossless compression here
  CGFloat screenshotCompressionQuality = usesScaling ? FBMaxCompressionQuality : compressionQuality;
  NSError *error;
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:self.mainScreenID
                                                           compressionQuality:screenshotCompressionQuality
                                                                          uti:(__bridge id)kUTTypeJPEG
                                                                      timeout:FRAME_TIMEOUT
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
    return;
  }

  if (usesScaling) {
    [self.imageScaler submitImage:screenshotData
                              uti:(__bridge id)kUTTypeJPEG
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
  @synchronized (self.listeningClients) {
    for (GCDAsyncSocket *client in self.listeningClients) {
      [client writeData:chunk withTimeout:-1 tag:0];
    }
  }
}

+ (BOOL)canStreamScreenshots
{
  return [FBScreenshot isNewScreenshotAPISupported];
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

@end
