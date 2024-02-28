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
#import "XCUIapplication.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIApplication+FBHelpers.h"

@implementation XCUIApplication (FBLaunch)

static char XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT;

@dynamic fb_didStartWithoutBlockingAlert;

- (void)setFb_didStartWithoutBlockingAlert:(NSNumber *)didStartWithoutBlockingAlert
{
  objc_setAssociatedObject(self, &XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT, 
                           didStartWithoutBlockingAlert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)fb_didStartWithoutBlockingAlert
{
  return objc_getAssociatedObject(self, &XCUIAPPLICATION_DID_START_WO_BLOCKING_ALERT);
}

- (void)fb_scheduleNextDispatchWithInterval:(NSTimeInterval)interval
                                timeStarted:(uint64_t)timeStarted
                                    timeout:(NSTimeInterval)timeout
                              exceptionName:(NSString *)exceptionName
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
      NSString *reason = [NSString stringWithFormat:@"The application '%@' cannot be launched because it is blocked by an unexpected system alert: %@", self.bundleID, alert.text];
      @throw [NSException exceptionWithName:exceptionName reason:reason userInfo:nil];
    }
    [self fb_scheduleNextDispatchWithInterval:interval
                                  timeStarted:timeStarted
                                      timeout:timeout
                                exceptionName:exceptionName];
  });
}

- (void)fb_launchWithInterruptingAlertCheckInterval:(NSTimeInterval)interval
                                      exceptionName:(NSString *)exceptionName
{
  self.fb_didStartWithoutBlockingAlert = @NO;
  [self fb_scheduleNextDispatchWithInterval:interval
                                timeStarted:clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
                                    timeout:65.
                              exceptionName:exceptionName];
  [self launch];
  self.fb_didStartWithoutBlockingAlert = @YES;
}

@end
