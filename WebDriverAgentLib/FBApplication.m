/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplication.h"

#import "FBLogger.h"
#import "FBRunLoopSpinner.h"
#import "FBMacros.h"
#import "FBActiveAppDetectionPoint.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCAccessibilityElement.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"
#import "FBXCAXClientProxy.h"


static const NSTimeInterval APP_STATE_CHANGE_TIMEOUT = 5.0;

@interface FBApplication ()
@end

@implementation FBApplication

+ (instancetype)fb_activeApplication
{
  return [self fb_activeApplicationWithDefaultBundleId:nil];
}

+ (NSArray<FBApplication *> *)fb_activeApplications
{
  NSArray<XCAccessibilityElement *> *activeApplicationElements = [FBXCAXClientProxy.sharedClient activeApplications];
  NSMutableArray<FBApplication *> *result = [NSMutableArray array];
  if (activeApplicationElements.count > 0) {
    for (XCAccessibilityElement *applicationElement in activeApplicationElements) {
      FBApplication *app = [FBApplication fb_applicationWithPID:applicationElement.processIdentifier];
      if (nil != app) {
        [result addObject:app];
      }
    }
  }
  return result.count > 0 ? result.copy : @[self.class.fb_systemApplication];
}

+ (instancetype)fb_activeApplicationWithDefaultBundleId:(nullable NSString *)bundleId
{
  NSArray<XCAccessibilityElement *> *activeApplicationElements = [FBXCAXClientProxy.sharedClient activeApplications];
  XCAccessibilityElement *activeApplicationElement = nil;
  XCAccessibilityElement *currentElement = nil;
  if (nil != bundleId) {
    currentElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
    if (nil != currentElement) {
      NSArray<NSDictionary *> *appInfos = [self fb_appsInfoWithAxElements:@[currentElement]];
      [FBLogger logFmt:@"Detected on-screen application: %@", appInfos.firstObject[@"bundleId"]];
      if ([[appInfos.firstObject objectForKey:@"bundleId"] isEqualToString:(id)bundleId]) {
        activeApplicationElement = currentElement;
      }
    }
  }
  if (nil == activeApplicationElement && activeApplicationElements.count > 1) {
    if (nil != bundleId) {
      NSArray<NSDictionary *> *appInfos = [self fb_appsInfoWithAxElements:activeApplicationElements];
      NSMutableArray<NSString *> *bundleIds = [NSMutableArray array];
      for (NSDictionary *appInfo in appInfos) {
        [bundleIds addObject:(NSString *)appInfo[@"bundleId"]];
      }
      [FBLogger logFmt:@"Detected system active application(s): %@", bundleIds];
      // Try to select the desired application first
      for (NSUInteger appIdx = 0; appIdx < appInfos.count; appIdx++) {
        if ([[[appInfos objectAtIndex:appIdx] objectForKey:@"bundleId"] isEqualToString:(id)bundleId]) {
          activeApplicationElement = [activeApplicationElements objectAtIndex:appIdx];
          break;
        }
      }
    }
    // Fall back to the "normal" algorithm if the desired application is either
    // not set or is not active
    if (nil == activeApplicationElement) {
      if (nil == currentElement) {
        currentElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
      }
      if (nil == currentElement) {
        [FBLogger log:@"Cannot precisely detect the current application. Will use the system's recently active one"];
        if (nil == bundleId) {
          [FBLogger log:@"Consider changing the 'defaultActiveApplication' setting to the bundle identifier of the desired application under test"];
        }
      } else {
        for (XCAccessibilityElement *appElement in activeApplicationElements) {
          if (appElement.processIdentifier == currentElement.processIdentifier) {
            activeApplicationElement = appElement;
            break;
          }
        }
      }
    }
  }

  if (nil != activeApplicationElement) {
    FBApplication *application = [FBApplication fb_applicationWithPID:activeApplicationElement.processIdentifier];
    if (nil != application) {
      return application;
    }
    [FBLogger log:@"Cannot translate the active process identifier into an application object"];
  }

  if (activeApplicationElements.count > 0) {
    [FBLogger logFmt:@"Getting the most recent active application (out of %@ total items)", @(activeApplicationElements.count)];
    for (XCAccessibilityElement *appElement in activeApplicationElements) {
      FBApplication *application = [FBApplication fb_applicationWithPID:appElement.processIdentifier];
      if (nil != application) {
        return application;
      }
    }
  }

  [FBLogger log:@"Cannot retrieve any active applications. Assuming the system application is the active one"];
  return [self fb_systemApplication];
}

+ (instancetype)fb_systemApplication
{
  return [self fb_applicationWithPID:
   [[FBXCAXClientProxy.sharedClient systemApplication] processIdentifier]];
}

+ (instancetype)appWithPID:(pid_t)processID
{
  if ([NSProcessInfo processInfo].processIdentifier == processID) {
    return nil;
  }
  return [super appWithPID:processID];
}

+ (instancetype)applicationWithPID:(pid_t)processID
{
  if ([NSProcessInfo processInfo].processIdentifier == processID) {
    return nil;
  }
  if ([FBXCAXClientProxy.sharedClient hasProcessTracker]) {
    return (FBApplication *)[FBXCAXClientProxy.sharedClient monitoredApplicationWithProcessIdentifier:processID];
  }
  return [super applicationWithPID:processID];
}

- (void)launch
{
  [super launch];
  if (![self fb_waitForAppElement:APP_STATE_CHANGE_TIMEOUT]) {
    [FBLogger logFmt:@"The application '%@' is not running in foreground after %.2f seconds", self.bundleID, APP_STATE_CHANGE_TIMEOUT];
  }
}

- (void)terminate
{
  [super terminate];
  if (![self waitForState:XCUIApplicationStateNotRunning timeout:APP_STATE_CHANGE_TIMEOUT]) {
    [FBLogger logFmt:@"The active application is still '%@' after %.2f seconds timeout", self.bundleID, APP_STATE_CHANGE_TIMEOUT];
  }
}

+ (BOOL)fb_switchToSystemApplicationWithError:(NSError **)error
{
  FBApplication *systemApp = self.fb_systemApplication;
  @try {
    if ([systemApp fb_state] < 2) {
      [systemApp launch];
    } else {
      [systemApp fb_activate];
    }
  } @catch (NSException *e) {
    return [[[FBErrorBuilder alloc]
             withDescription:nil == e ? @"Cannot open the home screen" : e.reason]
            buildError:error];
  }
  return [[[[FBRunLoopSpinner new]
            timeout:5]
           timeoutErrorMessage:@"Timeout waiting until the home screen is visible"]
          spinUntilTrue:^BOOL{
    FBApplication *activeApp = self.fb_activeApplication;
    return nil != activeApp && [activeApp.bundleID isEqualToString:systemApp.bundleID];
  }
          error:error];
}

@end
