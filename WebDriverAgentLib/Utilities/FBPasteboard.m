/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBPasteboard.h"

#import <mach/mach_time.h>
#import "FBAlert.h"
#import "FBErrorBuilder.h"
#import "FBMacros.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBAlert.h"

#define ALERT_TIMEOUT_SEC 30
// Must not be less than FB_MONTORING_INTERVAL in FBAlertsMonitor
#define ALERT_CHECK_INTERVAL_SEC 2

#if !TARGET_OS_TV
@implementation FBPasteboard

+ (BOOL)setData:(NSData *)data forType:(NSString *)type error:(NSError **)error
{
  UIPasteboard *pb = UIPasteboard.generalPasteboard;
  if ([type.lowercaseString isEqualToString:@"plaintext"]) {
    pb.string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  } else if ([type.lowercaseString isEqualToString:@"image"]) {
    UIImage *image = [UIImage imageWithData:data];
    if (nil == image) {
      NSString *description = @"No image can be parsed from the given pasteboard data";
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:description] build];
      }
      return NO;
    }
    pb.image = image;
  } else if ([type.lowercaseString isEqualToString:@"url"]) {
    NSString *urlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    if (nil == url) {
      NSString *description = @"No URL can be parsed from the given pasteboard data";
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:description] build];
      }
      return NO;
    }
    pb.URL = url;
  } else {
    NSString *description = [NSString stringWithFormat:@"Unsupported content type: %@", type];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return NO;
  }
  return YES;
}

+ (nullable id)pasteboardContentForItem:(NSString *)item
                               instance:(UIPasteboard *)pbInstance
                                timeout:(NSTimeInterval)timeout
                                  error:(NSError **)error
{
  SEL selector = NSSelectorFromString(item);
  NSMethodSignature *methodSignature = [pbInstance methodSignatureForSelector:selector];
  if (nil == methodSignature) {
    NSString *description = [NSString stringWithFormat:@"Cannot retrieve '%@' from a UIPasteboard instance", item];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return nil;
  }
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  [invocation setSelector:selector];
  [invocation setTarget:pbInstance];
  if (SYSTEM_VERSION_LESS_THAN(@"16.0")) {
    [invocation invoke];
    id __unsafe_unretained result;
    [invocation getReturnValue:&result];
    return result;
  }

  // https://github.com/appium/appium/issues/17392
  __block id pasteboardContent;
  dispatch_queue_t backgroundQueue = dispatch_queue_create("GetPasteboard", NULL);
  __block BOOL didFinishGetPasteboard = NO;
  dispatch_async(backgroundQueue, ^{
    [invocation invoke];
    id __unsafe_unretained result;
    [invocation getReturnValue:&result];
    pasteboardContent = result;
    didFinishGetPasteboard = YES;
  });
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
  while (!didFinishGetPasteboard) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:ALERT_CHECK_INTERVAL_SEC]];
    if (didFinishGetPasteboard) {
      break;
    }

    XCUIElement *alertElement = XCUIApplication.fb_systemApplication.fb_alertElement;
    if (nil != alertElement) {
      FBAlert *alert = [FBAlert alertWithElement:alertElement];
      [alert acceptWithError:nil];
    }
    uint64_t timeElapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted;
    if (timeElapsed / NSEC_PER_SEC > timeout) {
      NSString *description = [NSString stringWithFormat:@"Cannot handle pasteboard alert within %@s timeout", @(timeout)];
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:description] build];
      }
      return nil;
    }
  }
  return pasteboardContent;
}

+ (NSData *)dataForType:(NSString *)type error:(NSError **)error
{
  UIPasteboard *pb = UIPasteboard.generalPasteboard;
  if ([type.lowercaseString isEqualToString:@"plaintext"]) {
    if (pb.hasStrings) {
      id result = [self.class pasteboardContentForItem:@"strings"
                                              instance:pb
                                               timeout:ALERT_TIMEOUT_SEC
                                                 error:error
      ];
      return nil == result
        ? nil
        : [[(NSArray *)result componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    }
  } else if ([type.lowercaseString isEqualToString:@"image"]) {
    if (pb.hasImages) {
      id result = [self.class pasteboardContentForItem:@"image"
                                              instance:pb
                                               timeout:ALERT_TIMEOUT_SEC
                                                 error:error
      ];
      return nil == result ? nil : UIImagePNGRepresentation((UIImage *)result);
    }
  } else if ([type.lowercaseString isEqualToString:@"url"]) {
    if (pb.hasURLs) {
      id result = [self.class pasteboardContentForItem:@"URLs"
                                              instance:pb
                                               timeout:ALERT_TIMEOUT_SEC
                                                 error:error
      ];
      if (nil == result) {
        return nil;
      }
      NSMutableArray<NSString *> *urls = [NSMutableArray array];
      for (NSURL *url in (NSArray *)result) {
        if (nil != url.absoluteString) {
          [urls addObject:(id)url.absoluteString];
        }
      }
      return [[urls componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    }
  } else {
    NSString *description = [NSString stringWithFormat:@"Unsupported content type: %@", type];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return nil;
  }
  return [@"" dataUsingEncoding:NSUTF8StringEncoding];
}

@end
#endif
