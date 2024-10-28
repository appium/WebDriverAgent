/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSession.h"
#import "FBSession-Private.h"

#import <objc/runtime.h>

#import "FBXCAccessibilityElement.h"
#import "FBAlertsMonitor.h"
#import "FBConfiguration.h"
#import "FBElementCache.h"
#import "FBExceptions.h"
#import "FBMacros.h"
#import "FBScreenRecordingContainer.h"
#import "FBScreenRecordingPromise.h"
#import "FBScreenRecordingRequest.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIElement.h"

/*!
 The intial value for the default application property.
 Setting this value to `defaultActiveApplication` property forces WDA to use the internal
 automated algorithm to determine the active on-screen application
 */
NSString *const FBDefaultApplicationAuto = @"auto";

NSString *const FB_SAFARI_BUNDLE_ID = @"com.apple.mobilesafari";

@interface FBSession ()
@property (nullable, nonatomic) XCUIApplication *testedApplication;
@property (nonatomic) BOOL isTestedApplicationExpectedToRun;
@property (nonatomic) BOOL shouldAppsWaitForQuiescence;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, readwrite) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;
@end

@interface FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert;

@end

@implementation FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert
{
  if (nil == self.defaultAlertAction || 0 == self.defaultAlertAction.length) {
    return;
  }

  NSError *error;
  if ([self.defaultAlertAction isEqualToString:@"accept"]) {
    if (![alert acceptWithError:&error]) {
      [FBLogger logFmt:@"Cannot accept the alert. Original error: %@", error.description];
    }
  } else if ([self.defaultAlertAction isEqualToString:@"dismiss"]) {
    if (![alert dismissWithError:&error]) {
      [FBLogger logFmt:@"Cannot dismiss the alert. Original error: %@", error.description];
    }
  } else {
    [FBLogger logFmt:@"'%@' default alert action is unsupported", self.defaultAlertAction];
  }
}

@end

@implementation FBSession

static FBSession *_activeSession = nil;

+ (instancetype)activeSession
{
  return _activeSession;
}

+ (void)markSessionActive:(FBSession *)session
{
  if (_activeSession) {
    [_activeSession kill];
  }
  _activeSession = session;
}

+ (instancetype)sessionWithIdentifier:(NSString *)identifier
{
  if (!identifier) {
    return nil;
  }
  if (![identifier isEqualToString:_activeSession.identifier]) {
    return nil;
  }
  return _activeSession;
}

+ (instancetype)initWithApplication:(XCUIApplication *)application
{
  FBSession *session = [FBSession new];
  session.useNativeCachingStrategy = YES;
  session.alertsMonitor = nil;
  session.defaultAlertAction = nil;
  session.elementsVisibilityCache = [NSMutableDictionary dictionary];
  session.identifier = [[NSUUID UUID] UUIDString];
  session.defaultActiveApplication = FBDefaultApplicationAuto;
  session.testedApplication = nil;
  session.isTestedApplicationExpectedToRun = nil != application && application.running;
  if (application) {
    session.testedApplication = application;
    session.shouldAppsWaitForQuiescence = application.fb_shouldWaitForQuiescence;
  }
  session.elementCache = [FBElementCache new];
  [FBSession markSessionActive:session];
  return session;
}

+ (instancetype)initWithApplication:(nullable XCUIApplication *)application
                 defaultAlertAction:(NSString *)defaultAlertAction
{
  FBSession *session = [self.class initWithApplication:application];
  session.alertsMonitor = [[FBAlertsMonitor alloc] init];
  session.alertsMonitor.delegate = (id<FBAlertsMonitorDelegate>)session;
  session.defaultAlertAction = [defaultAlertAction lowercaseString];
  [session.alertsMonitor enable];
  return session;
}

- (void)kill
{
  if (nil == _activeSession) {
    return;
  }

  if (nil != self.alertsMonitor) {
    [self.alertsMonitor disable];
    self.alertsMonitor = nil;
  }

  FBScreenRecordingPromise *activeScreenRecording = FBScreenRecordingContainer.sharedInstance.screenRecordingPromise;
  if (nil != activeScreenRecording) {
    NSError *error;
    if (![FBXCTestDaemonsProxy stopScreenRecordingWithUUID:activeScreenRecording.identifier error:&error]) {
      [FBLogger logFmt:@"%@", error];
    }
    [FBScreenRecordingContainer.sharedInstance reset];
  }

  if (nil != self.testedApplication
      && FBConfiguration.shouldTerminateApp
      && self.testedApplication.running
      && ![self.testedApplication fb_isSameAppAs:XCUIApplication.fb_systemApplication]) {
    @try {
      [self.testedApplication terminate];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"%@", e.description];
    }
  }

  _activeSession = nil;
}

- (XCUIApplication *)activeApplication
{
  BOOL isAuto = [self.defaultActiveApplication isEqualToString:FBDefaultApplicationAuto];
  NSString *defaultBundleId = isAuto ? nil : self.defaultActiveApplication;

  if (nil != defaultBundleId && [self applicationStateWithBundleId:defaultBundleId] >= XCUIApplicationStateRunningForeground) {
    return [self makeApplicationWithBundleId:defaultBundleId];
  }

  if (nil != self.testedApplication) {
    XCUIApplicationState testedAppState = self.testedApplication.state;
    if (testedAppState >= XCUIApplicationStateRunningForeground) {
      // We look for `SBTransientOverlayWindow` elements for half modals. See https://github.com/appium/WebDriverAgent/pull/946
      NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"%K == %@ OR %K == %@",
                                      @"elementType", @(XCUIElementTypeAlert), 
                                      @"identifier", @"SBTransientOverlayWindow"];
      if ([FBConfiguration shouldRespectSystemAlerts]
          && [[XCUIApplication.fb_systemApplication descendantsMatchingType:XCUIElementTypeAny]
              matchingPredicate:searchPredicate].count > 0) {
        return XCUIApplication.fb_systemApplication;
      }
      return (XCUIApplication *)self.testedApplication;
    }
    if (self.isTestedApplicationExpectedToRun && testedAppState <= XCUIApplicationStateNotRunning) {
      NSString *description = [NSString stringWithFormat:@"The application under test with bundle id '%@' is not running, possibly crashed", self.testedApplication.bundleID];
      @throw [NSException exceptionWithName:FBApplicationCrashedException reason:description userInfo:nil];
    }
  }

  return [XCUIApplication fb_activeApplicationWithDefaultBundleId:defaultBundleId];
}

- (XCUIApplication *)launchApplicationWithBundleId:(NSString *)bundleIdentifier
                           shouldWaitForQuiescence:(nullable NSNumber *)shouldWaitForQuiescence
                                         arguments:(nullable NSArray<NSString *> *)arguments
                                       environment:(nullable NSDictionary <NSString *, NSString *> *)environment
{
  XCUIApplication *app = [self makeApplicationWithBundleId:bundleIdentifier];
  if (nil == shouldWaitForQuiescence) {
    // Iherit the quiescence check setting from the main app under test by default
    app.fb_shouldWaitForQuiescence = nil != self.testedApplication && self.shouldAppsWaitForQuiescence;
  } else {
    app.fb_shouldWaitForQuiescence = [shouldWaitForQuiescence boolValue];
  }
  if (!app.running) {
    app.launchArguments = arguments ?: @[];
    app.launchEnvironment = environment ?: @{};
    [app launch];
  } else {
    [app activate];
  }
  if ([app fb_isSameAppAs:self.testedApplication]) {
    self.isTestedApplicationExpectedToRun = YES;
  }
  return app;
}

- (XCUIApplication *)activateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  XCUIApplication *app = [self makeApplicationWithBundleId:bundleIdentifier];
  [app activate];
  return app;
}

- (BOOL)terminateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  XCUIApplication *app = [self makeApplicationWithBundleId:bundleIdentifier];
  if ([app fb_isSameAppAs:self.testedApplication]) {
    self.isTestedApplicationExpectedToRun = NO;
  }
  if (app.running) {
    [app terminate];
    return YES;
  }
  return NO;
}

- (NSUInteger)applicationStateWithBundleId:(NSString *)bundleIdentifier
{
  return [self makeApplicationWithBundleId:bundleIdentifier].state;
}

- (XCUIApplication *)makeApplicationWithBundleId:(NSString *)bundleIdentifier
{
  return nil != self.testedApplication && [bundleIdentifier isEqualToString:(NSString *)self.testedApplication.bundleID]
    ? self.testedApplication
    : [[XCUIApplication alloc] initWithBundleIdentifier:bundleIdentifier];
}

@end
