/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
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

// +[XCUIApplication fb_systemApplication] goes through FBXCAXClientProxy's shared accessibility
// channel, which can be stuck for as long as some other in-flight request against a frozen app -
// see -fb_isTestedApplicationSameAsSystemAppWithTimeout: below.
static const NSTimeInterval FB_IS_SYSTEM_APP_CHECK_TIMEOUT_SEC = 5.;
NSString *const FBSessionWasKilledNotification = @"FBSessionWasKilledNotification";

@interface FBSession ()
@property (nullable, nonatomic) XCUIApplication *testedApplication;
@property (nonatomic) BOOL isTestedApplicationExpectedToRun;
@property (nonatomic) BOOL shouldAppsWaitForQuiescence;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, readwrite) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;

- (BOOL)fb_isTestedApplicationSameAsSystemAppWithTimeout:(NSTimeInterval)timeout;
@end

@interface FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert;

@end

@implementation FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert
{
  NSString *autoClickAlertSelector = FBConfiguration.sharedInstance.autoClickAlertSelector;
  if ([autoClickAlertSelector length] > 0) {
    @try {
      [alert clickElementMatchingClassChain:autoClickAlertSelector];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"Could not click at the alert element '%@'. Original error: %@",
        autoClickAlertSelector, e.reason];
    }
    // This setting has priority over other settings if enabled
    return;
  }

  if (nil == self.defaultAlertAction || 0 == self.defaultAlertAction.length) {
    return;
  }

  if ([self.defaultAlertAction isEqualToString:@"accept"]) {
    @try {
      [alert accept];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"Cannot accept the alert. Original error: %@", e.reason];
    }
  } else if ([self.defaultAlertAction isEqualToString:@"dismiss"]) {
    @try {
      [alert dismiss];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"Cannot dismiss the alert. Original error: %@", e.reason];
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
  session.defaultAlertAction = [defaultAlertAction lowercaseString];
  [session enableAlertsMonitor];
  return session;
}

- (BOOL)enableAlertsMonitor
{
  if (nil != self.alertsMonitor) {
    return NO;
  }

  self.alertsMonitor = [[FBAlertsMonitor alloc] init];
  self.alertsMonitor.delegate = (id<FBAlertsMonitorDelegate>)self;
  [self.alertsMonitor enable];
  return YES;
}

- (BOOL)disableAlertsMonitor
{
  if (nil == self.alertsMonitor) {
    return NO;
  }

  [self.alertsMonitor disable];
  self.alertsMonitor = nil;
  return YES;
}

- (void)kill
{
  if (nil == _activeSession) {
    return;
  }

  // Cleared up front, before the (potentially slow) teardown below - not just at the very end -
  // so that any request which arrives while that teardown is still running resolves to "no such
  // session" (see +sessionWithIdentifier:) instead of racing in against a session that's already
  // mid-teardown, and unlike the notification below, would never get abandoned either.
  if (self == _activeSession) {
    _activeSession = nil;
  }

  // Posted early, before the (potentially slow) teardown below, so anything waiting on this
  // session's pending HTTP requests can stop waiting as soon as possible.
  [NSNotificationCenter.defaultCenter postNotificationName:FBSessionWasKilledNotification object:self];

  [self disableAlertsMonitor];

  FBScreenRecordingPromise *activeScreenRecording = FBScreenRecordingContainer.sharedInstance.screenRecordingPromise;
  if (nil != activeScreenRecording) {
    NSError *error;
    if (![FBXCTestDaemonsProxy stopScreenRecordingWithUUID:activeScreenRecording.identifier error:&error]) {
      [FBLogger logFmt:@"%@", error];
    }
    [FBScreenRecordingContainer.sharedInstance reset];
  }

  if (nil != self.testedApplication
      && FBConfiguration.sharedInstance.shouldTerminateApp
      && self.testedApplication.running
      && ![self fb_isTestedApplicationSameAsSystemAppWithTimeout:FB_IS_SYSTEM_APP_CHECK_TIMEOUT_SEC]) {
    @try {
      [self.testedApplication terminate];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"%@", e.description];
    }
  }
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
      NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"%K == %@ OR %K IN {%@, %@}",
                                      @"elementType", @(XCUIElementTypeAlert),
                                      // To look for `SBTransientOverlayWindow` elements. See https://github.com/appium/WebDriverAgent/pull/946
                                      @"identifier", @"SBTransientOverlayWindow",
                                      // To look for 'criticalAlertSetting' elements https://developer.apple.com/documentation/usernotifications/unnotificationsettings/criticalalertsetting
                                      // See https://github.com/appium/appium/issues/20835
                                      @"NotificationShortLookView"];
      if (FBConfiguration.sharedInstance.shouldRespectSystemAlerts
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

// +[XCUIApplication fb_systemApplication] has no async variant and can block for as long as
// FBXCAXClientProxy's shared accessibility channel is busy servicing some other (possibly stuck)
// request against a frozen app, unrelated to this session. Run it on its own thread and give up
// after `timeout`, assuming the tested app IS the system app - the safer assumption, since it
// means -kill skips terminating it rather than risking terminating springboard - if we can't find
// out in time.
- (BOOL)fb_isTestedApplicationSameAsSystemAppWithTimeout:(NSTimeInterval)timeout
{
  __block XCUIApplication *systemApp = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    systemApp = XCUIApplication.fb_systemApplication;
    dispatch_semaphore_signal(sem);
  });
  int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    [FBLogger logFmt:@"Could not determine the system application within %@ seconds; assuming '%@' might be it and skipping its termination", @(timeout), self.testedApplication.bundleID];
    return YES;
  }
  return [self.testedApplication fb_isSameAppAs:systemApp];
}

@end
