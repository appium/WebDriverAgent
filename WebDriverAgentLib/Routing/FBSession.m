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
// -[XCUIApplication terminate] hard-asserts off the main thread - see
// -fb_terminateTestedApplicationWithTimeout: below.
static const NSTimeInterval FB_APP_TERMINATE_TIMEOUT_SEC = 5.;
// Upper bound on -kill's own teardown (system-app check + terminate above, plus the existing 20s
// bound on stopping an active screen recording - see FBXCTestDaemonsProxy) - how long a caller that
// lost the -kill race below will wait for the winner to actually finish, rather than proceeding
// immediately against a session that's still mid-teardown.
static const NSTimeInterval FB_KILL_WAIT_TIMEOUT_SEC = 35.;
NSString *const FBSessionWasKilledNotification = @"FBSessionWasKilledNotification";

@interface FBSession ()
@property (nullable, nonatomic) XCUIApplication *testedApplication;
@property (nonatomic) BOOL isTestedApplicationExpectedToRun;
@property (nonatomic) BOOL shouldAppsWaitForQuiescence;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, readwrite) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;
// Lets a -kill caller that loses the atomic race in -kill wait for the winner's teardown to
// actually finish, instead of returning immediately. Created once per session instance - see -init.
@property (nonatomic, strong, readonly) NSCondition *killCondition;
@property (nonatomic, assign) BOOL isKillFinished;

- (BOOL)fb_isTestedApplicationSameAsSystemAppWithTimeout:(NSTimeInterval)timeout;
- (void)fb_terminateTestedApplicationWithTimeout:(NSTimeInterval)timeout;
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

- (instancetype)init
{
  if ((self = [super init])) {
    _killCondition = [NSCondition new];
  }
  return self;
}

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
  // DELETE /session and session creation now run concurrently (both can bypass the frozen route
  // queue), so a session that's already been superseded by a newer one can still reach here via a
  // stale reference. Check-and-clear must happen as one atomic step, else a belated -kill on the
  // old session could win the write race and null out the new session's pointer instead of its
  // own. self != _activeSession means someone else already killed/replaced this session - nothing
  // left for us to do.
  BOOL wasActive;
  @synchronized (self.class) {
    wasActive = (self == _activeSession);
    if (wasActive) {
      _activeSession = nil;
    }
  }
  if (!wasActive) {
    // Someone else is already tearing this exact session down (e.g. a concurrent DELETE and the
    // pre-kill in session creation both targeting it). Wait for that teardown to actually finish,
    // bounded, so a caller that's about to act as if the session is gone - e.g. launching a fresh
    // app for a replacement session - doesn't race a still-in-flight -terminate.
    [self.killCondition lock];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:FB_KILL_WAIT_TIMEOUT_SEC];
    while (!self.isKillFinished && [self.killCondition waitUntilDate:deadline]) {
      // Re-checks isKillFinished on every wake, in case of a spurious wakeup.
    }
    [self.killCondition unlock];
    return;
  }

  @try {
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
      [self fb_terminateTestedApplicationWithTimeout:FB_APP_TERMINATE_TIMEOUT_SEC];
    }
  } @finally {
    [self.killCondition lock];
    self.isKillFinished = YES;
    [self.killCondition broadcast];
    [self.killCondition unlock];
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
  __block NSException *caughtException = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    // +fb_systemApplication is undocumented private API; some of its XCUIApplication siblings
    // (e.g. -terminate) hard-assert when called off the main thread, so guard against this one
    // doing the same on some other Xcode/iOS version - an uncaught exception thrown from inside a
    // bare dispatch_async block has no handler and would crash the whole process.
    @try {
      systemApp = XCUIApplication.fb_systemApplication;
    } @catch (NSException *e) {
      caughtException = e;
    }
    dispatch_semaphore_signal(sem);
  });
  int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs)) || nil != caughtException) {
    [FBLogger logFmt:@"Could not determine the system application within %@ seconds%@; assuming '%@' might be it and skipping its termination", @(timeout), nil == caughtException ? @"" : [NSString stringWithFormat:@" (%@)", caughtException.description], self.testedApplication.bundleID];
    return YES;
  }
  return [self.testedApplication fb_isSameAppAs:systemApp];
}

// -[XCUIApplication terminate] hard-asserts when called off the main thread, but -kill (the only
// caller) can now itself run on a background queue - DELETE /session is a standalone route (see
// FBHTTPServer.m) that bypasses the main routeQueue. Dispatching to main and waiting indefinitely
// would reintroduce the exact hang standalone routes exist to avoid, if that's the queue currently
// stuck servicing some other request against the frozen app; give up after `timeout` instead. The
// dispatched block still runs (and still terminates the app) whenever main frees up, even after
// this method has given up waiting on it.
- (void)fb_terminateTestedApplicationWithTimeout:(NSTimeInterval)timeout
{
  XCUIApplication *application = self.testedApplication;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      [application terminate];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"%@", e.description];
    }
    dispatch_semaphore_signal(sem);
  });
  int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    [FBLogger logFmt:@"Could not terminate '%@' within %@ seconds; the main thread may still be busy servicing another request", application.bundleID, @(timeout)];
  }
}

@end
