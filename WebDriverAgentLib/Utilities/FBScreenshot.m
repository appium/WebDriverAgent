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

+ (NSData *)takeWithQuality:(NSUInteger)quality
                       rect:(CGRect)rect
                      error:(NSError **)error
{
  if ([self.class isNewScreenshotAPISupported]) {
    return [XCUIScreen.mainScreen screenshotDataForQuality:FBConfiguration.screenshotQuality
                                                      rect:rect
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
    return [XCUIScreen.mainScreen screenshotDataForQuality:quality
                                                      rect:CGRectNull
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
                     quality:(CGFloat)quality
                        rect:(CGRect)rect
                         uti:(NSString *)uti
{
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  __block NSData *screenshotData = nil;
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
  int64_t timeoutNs = (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    [FBLogger logFmt:@"Cannot take a screenshot within %@ timeout", formatTimeInterval(SCREENSHOT_TIMEOUT)];
  };
  return screenshotData;
}

@end
