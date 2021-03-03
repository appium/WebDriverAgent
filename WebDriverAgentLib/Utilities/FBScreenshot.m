/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenshot.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCUIDevice.h"
#import "XCUIScreen.h"
#import "XCUIScreenDataSource-Protocol.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 20.;
static const NSTimeInterval FRAME_TIMEOUT = 1.;
static const CGFloat HIGH_QUALITY = 0.8;
static const CGFloat LOW_QUALITY = 0.2;

NSString *formatTimeInterval(NSTimeInterval interval) {
  NSUInteger milliseconds = (NSUInteger)(interval * 1000);
  return [NSString stringWithFormat:@"%ld ms", milliseconds];
}

@implementation FBScreenshot

+ (BOOL)isNewScreenshotAPISupported
{
  static dispatch_once_t newScreenshotAPISupported;
  static BOOL result;
  dispatch_once(&newScreenshotAPISupported, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
}

+ (CGFloat)compressionQualityWithQuality:(NSUInteger)quality
{
  switch (quality) {
    case 1:
      return HIGH_QUALITY;
    case 2:
      return LOW_QUALITY;
    default:
      return 1.0;
  }
}

+ (NSString *)imageUtiWithQuality:(NSUInteger)quality
{
  switch (quality) {
    case 1:
    case 2:
      return (__bridge id)kUTTypeJPEG;
    default:
      return (__bridge id)kUTTypePNG;
  }
}

+ (NSData *)takeWithQuality:(NSUInteger)quality
                       rect:(CGRect)rect
                      error:(NSError **)error
{
  if ([self.class isNewScreenshotAPISupported]) {
    XCUIScreen *mainScreen = XCUIScreen.mainScreen;
    return [self.class takeWithScreenID:mainScreen.displayID
                                  scale:mainScreen.scale
                     compressionQuality:[self.class compressionQualityWithQuality:FBConfiguration.screenshotQuality]
                                   rect:rect
                                    uti:[self.class imageUtiWithQuality:FBConfiguration.screenshotQuality]
                                  error:error];
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
    XCUIScreen *mainScreen = XCUIScreen.mainScreen;
    return [self.class takeWithScreenID:mainScreen.displayID
                                  scale:mainScreen.scale
                     compressionQuality:[self.class compressionQualityWithQuality:FBConfiguration.screenshotQuality]
                                   rect:CGRectNull
                                    uti:[self.class imageUtiWithQuality:FBConfiguration.screenshotQuality]
                                  error:error];
  }

  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  __block NSData *screenshotData = nil;
  __block NSError *innerError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotWithReply:^(NSData *data, NSError *screenshotError) {
    if (nil == screenshotError) {
      screenshotData = data;
    } else {
      innerError = screenshotError;
    }
    dispatch_semaphore_signal(sem);
  }];
  if (nil != innerError && error) {
    *error = innerError;
  }
  int64_t timeoutNs = (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    [[[FBErrorBuilder builder]
      withDescription:[NSString stringWithFormat:@"Cannot take a screenshot within %@ timeout", formatTimeInterval(SCREENSHOT_TIMEOUT)]]
     buildError:error];
  };
  return screenshotData;
}

+ (NSData *)takeWithScreenID:(unsigned int)screenID
                       scale:(CGFloat)scale
          compressionQuality:(CGFloat)compressionQuality
                        rect:(CGRect)rect
                         uti:(NSString *)uti
                       error:(NSError **)error
{
  __block NSData *screenshotData = nil;
  __block NSError *innerError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [XCUIDevice.sharedDevice.screenDataSource requestScreenshotOfScreenWithID:screenID
                                                                   withRect:rect
   // it looks like this API ignores `scale` value and always applies the actual
   // device's screen scale factor, which is OK for us
                                                                      scale:scale
                                                                  formatUTI:uti
                                                         compressionQuality:compressionQuality
                                                                  withReply:^(NSData *data, NSError *err) {
    if (nil != err) {
      [FBLogger logFmt:@"Got an error while taking a screenshot: %@", [err description]];
      innerError = err;
    } else {
      screenshotData = data;
    }
    dispatch_semaphore_signal(sem);
  }];
  if (nil != error && innerError) {
    *error = innerError;
  }
  int64_t timeoutNs = (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    NSString *timeoutMsg = [NSString stringWithFormat:@"Cannot take a screenshot within %@ timeout", formatTimeInterval(SCREENSHOT_TIMEOUT)];
    if (nil == error) {
      [FBLogger log:timeoutMsg];
    } else {
      [[[FBErrorBuilder builder]
        withDescription:timeoutMsg]
       buildError:error];
    }
  };
  return screenshotData;
}

+ (NSData *)takeWithScreenID:(unsigned int)screenID
          compressionQuality:(CGFloat)compressionQuality
                         uti:(NSString *)uti
                       error:(NSError **)error
{
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  __block NSData *screenshotData = nil;
  __block NSError *innerError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestScreenshotOfScreenWithID:screenID
                                     withRect:CGRectNull
                                          uti:uti
                           compressionQuality:compressionQuality
                                    withReply:^(NSData *data, NSError *err) {
    if (nil != err) {
      [FBLogger logFmt:@"Got an error while taking a screenshot: %@", [err description]];
      innerError = err;
    } else {
      screenshotData = data;
    }
    dispatch_semaphore_signal(sem);
  }];
  if (nil != error && innerError) {
    *error = innerError;
  }
  int64_t timeoutNs = (int64_t)(FRAME_TIMEOUT * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    NSString *timeoutMsg = [NSString stringWithFormat:@"Cannot take a screenshot within %@ timeout", formatTimeInterval(SCREENSHOT_TIMEOUT)];
    if (nil == error) {
      [FBLogger log:timeoutMsg];
    } else {
      [[[FBErrorBuilder builder]
        withDescription:timeoutMsg]
       buildError:error];
    }
  };
  return screenshotData;
}

@end
