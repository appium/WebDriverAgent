/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

@import CocoaAsyncSocket;

#import "FBApplication.h"
#import "FBMjpegServer.h"
#import "XCUIDevice+FBHelpers.h"

static const NSTimeInterval FPS = 10;
static NSString *const SERVER_NAME = @"WDA MJPEG Server";

@interface FBMjpegServer()

@property (nonatomic) NSTimer *mainTimer;
@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *activeClients;
@property (atomic) CGRect screenRect;

@end

@implementation FBMjpegServer


- (instancetype)init
{
  if ((self = [super init])) {
    _activeClients = [NSMutableArray array];
    _backgroundQueue = dispatch_queue_create("Background screenshoting", DISPATCH_QUEUE_SERIAL);
    _mainTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FPS repeats:YES block:^(NSTimer * _Nonnull timer) {
      @synchronized (self.activeClients) {
        if (0 == self.activeClients.count) {
          return;
        }
      }

      if (CGRectIsEmpty(self.screenRect)) {
        return;
      }
      NSData *screenshotData = [[XCUIDevice sharedDevice] fb_rawScreenshotWithQuality:2 rect:self.screenRect error:nil];
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
    }];
  }
  return self;
}

- (void)refreshScreenRect
{
  dispatch_async(dispatch_get_main_queue(), ^{
    FBApplication *systemApp = FBApplication.fb_systemApplication;
    UIInterfaceOrientation orientation = systemApp.interfaceOrientation;
    CGRect screenRect = [systemApp frame];
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
      CGFloat previousWidth = screenRect.size.width;
      CGFloat previousHeigth = screenRect.size.height;
      screenRect.size.width = previousHeigth;
      screenRect.size.height = previousWidth;
    }
    self.screenRect = screenRect;
  });
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient activeClients:(NSArray<GCDAsyncSocket *> *)activeClients
{
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
  @synchronized (self.activeClients) {
    [self.activeClients removeAllObjects];
    [self.activeClients addObjectsFromArray:activeClients];
  }
}

@end
