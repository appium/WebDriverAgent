/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenshot.h"

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCUIScreen.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = .5;

static NSLock *screenshotLock;

@implementation FBScreenshot

+ (void)load
{
  screenshotLock = [NSLock new];
}

+ (BOOL)isNewScreenshotAPISupported
{
  static dispatch_once_t newScreenshotAPISupported;
  static BOOL result;
  dispatch_once(&newScreenshotAPISupported, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
}

+ (NSData *)takeWithQuality:(NSUInteger)quality
                       rect:(CGRect)rect
                      error:(NSError **)error
{
  if ([self.class isNewScreenshotAPISupported]) {
    [screenshotLock lock];
    @try {
      return [XCUIScreen.mainScreen screenshotDataForQuality:FBConfiguration.screenshotQuality
                                                        rect:rect
                                                       error:error];
    } @finally {
      [screenshotLock unlock];
    }
  }

  [[[FBErrorBuilder builder]
         withDescription:@"Screenshots of limited areas are only available for newer OS versions"]
        buildError:error];
  return nil;
}

+ (NSData *)takeWithQuality:(NSUInteger)quality
                      error:(NSError **)error
{
  if ([self.class isNewScreenshotAPISupported]) {
    [screenshotLock lock];
    @try {
      return [XCUIScreen.mainScreen screenshotDataForQuality:quality
                                                        rect:CGRectNull
                                                       error:error];
    } @finally {
      [screenshotLock unlock];
    }
  }

  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  __block NSData *screenshotData = nil;
  __block NSError *innerError = nil;
  [screenshotLock lock];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotWithReply:^(NSData *data, NSError *screenshotError) {
    screenshotData = data;
    innerError = screenshotError;
    dispatch_semaphore_signal(sem);
  }];
  if (nil != innerError && error) {
    *error = innerError;
  }
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  [screenshotLock unlock];
  return screenshotData;
}

+ (NSData *)takeWithScreenID:(unsigned int)screenID
                     quality:(CGFloat)quality
                        rect:(CGRect)rect
                         uti:(NSString *)uti
{
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  __block NSData *screenshotData = nil;
  [screenshotLock lock];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotOfScreenWithID:screenID
                                     withRect:CGRectNull
                                          uti:uti
                           compressionQuality:quality
                                    withReply:^(NSData *data, NSError *error) {
    if (nil != error) {
      [FBLogger logFmt:@"Got an error while taking a screenshot: %@", [error description]];
    } else {
      screenshotData = data;
    }
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  [screenshotLock unlock];
  return screenshotData;
}

@end
