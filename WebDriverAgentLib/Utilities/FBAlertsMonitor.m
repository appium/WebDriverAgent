/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAlertsMonitor.h"

#import "FBAlert.h"
#import "FBLogger.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIApplication+FBHelpers.h"

static const NSTimeInterval FB_MONTORING_INTERVAL = 2.0;

// The iOS 18+ limited access permission prompt runs in a dedicated process that
// is not reported by fb_activeApplications. See https://github.com/appium/appium/issues/20591
static NSString *const FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID = @"com.apple.ContactsUI.LimitedAccessPromptView";

@interface FBAlertsMonitor()

@property (atomic) BOOL isMonitoring;

@end

@implementation FBAlertsMonitor

- (instancetype)init
{
  if ((self = [super init])) {
    _isMonitoring = NO;
    _delegate = nil;
  }
  return self;
}

- (void)scheduleNextTick
{
  if (!self.isMonitoring) {
    return;
  }

  dispatch_time_t delta = (int64_t)(FB_MONTORING_INTERVAL * NSEC_PER_SEC);

  if (nil == self.delegate) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), ^{
      [self scheduleNextTick];
    });
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    id<FBAlertsMonitorDelegate> delegate = self.delegate;
    NSArray<XCUIApplication *> *activeApps = XCUIApplication.fb_activeApplications;
    XCUIElement *alertElement = nil;
    for (XCUIApplication *activeApp in activeApps) {
      @try {
        alertElement = activeApp.fb_alertElement;
        if (nil != alertElement) {
          [delegate didDetectAlert:[FBAlert alertWithElement:alertElement]];
        }
      } @catch (NSException *e) {
        [FBLogger logFmt:@"Got an unexpected exception while monitoring alerts: %@\n%@", e.reason, e.callStackSymbols];
      }
      if (nil != alertElement) {
        break;
      }
    }

    if (nil == alertElement) {
      alertElement = [self fb_alertElementFromLimitedAccessPrompt];
      if (nil != alertElement) {
        [delegate didDetectAlert:[FBAlert alertWithElement:alertElement]];
      }
    }

    if (self.isMonitoring) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), ^{
        [self scheduleNextTick];
      });
    }
  });
}

- (XCUIElement *)fb_alertElementFromLimitedAccessPrompt
{
  @try {
    XCUIApplication *promptApp = [[XCUIApplication alloc]
                                  initWithBundleIdentifier:FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID];
    return promptApp.fb_alertElement;
  } @catch (NSException *e) {
    [FBLogger logFmt:@"Got an unexpected exception while monitoring the limited access prompt: %@\n%@", e.reason, e.callStackSymbols];
    return nil;
  }
}

- (void)enable
{
  if (self.isMonitoring) {
    return;
  }

  self.isMonitoring = YES;
  [self scheduleNextTick];
}

- (void)disable
{
  if (!self.isMonitoring) {
    return;
  }

  self.isMonitoring = NO;
}

@end
