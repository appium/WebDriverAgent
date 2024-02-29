/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBLaunch.h"

#import <objc/runtime.h>

#import "FBAlert.h"
#import "FBLogger.h"
#import "FBErrorBuilder.h"
#import "XCUIapplication.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIApplication+FBHelpers.h"

@implementation XCUIApplication (FBLaunch)

static char XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT;
static char XCUIAPPLICATION_BLOCKING_ALERT_TEXT;

@dynamic fb_didStartWithoutBlockingAlert;
@dynamic fb_blockingAlertText;

- (void)setFb_didStartWithoutBlockingAlert:(NSNumber *)didStartWithoutBlockingAlert
{
  objc_setAssociatedObject(self, &XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT, 
                           didStartWithoutBlockingAlert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)fb_didStartWithoutBlockingAlert
{
  return objc_getAssociatedObject(self, &XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT);
}

- (void)setFb_blockingAlertText:(NSString *)blockingAlertText
{
  objc_setAssociatedObject(self, &XCUIAPPLICATION_BLOCKING_ALERT_TEXT,
                           blockingAlertText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)fb_blockingAlertText
{
  return objc_getAssociatedObject(self, &XCUIAPPLICATION_BLOCKING_ALERT_TEXT);
}

- (void)fb_scheduleNextDispatchWithInterval:(NSTimeInterval)interval
                                timeStarted:(uint64_t)timeStarted
                                    timeout:(NSTimeInterval)timeout
{
  dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (interval * NSEC_PER_SEC));
  dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
    NSTimeInterval duration = (clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted) / NSEC_PER_SEC;
    if ([self.fb_didStartWithoutBlockingAlert boolValue] || duration > timeout) {
      return;
    }

    FBAlert *alert = nil;
    @try {
      XCUIElement *alertElement = [self.class.fb_systemApplication fb_alertElement];
      if (nil != alertElement) {
        alert = [FBAlert alertWithElement:alertElement];
      }
    } @catch (NSException *e) {
      [FBLogger logFmt:@"Got an unexpected exception while checking for system alerts: %@\n%@", e.reason, e.callStackSymbols];
    }
    if (nil != alert) {
      self.fb_blockingAlertText = alert.text;
      [self terminate];
      return;
    }
    [self fb_scheduleNextDispatchWithInterval:interval
                                  timeStarted:timeStarted
                                      timeout:timeout];
  });
}

- (BOOL)fb_launchWithInterruptingAlertCheckInterval:(NSTimeInterval)interval
                                              error:(NSError **)error
{
  self.fb_didStartWithoutBlockingAlert = @NO;
  self.fb_blockingAlertText = nil;
  [self fb_scheduleNextDispatchWithInterval:interval
                                timeStarted:clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
                                    timeout:65.];
  @try {
    [self launch];
    self.fb_didStartWithoutBlockingAlert = @YES;
    return YES;
  } @catch (NSException *e) {
    if (nil == self.fb_blockingAlertText) {
      self.fb_didStartWithoutBlockingAlert = @YES;
      return [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The application '%@' cannot be launched because of an unexpected error: %@", self.bundleID, e.reason]
       buildError:error];;
    }
  }
  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"The application '%@' cannot be launched because it is blocked by an unexpected system alert: %@", self.bundleID, self.fb_blockingAlertText]
          buildError:error];;
}

@end
