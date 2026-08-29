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

// FBXCAXClientProxy's shared accessibility channel can be stuck servicing another request.
static const NSTimeInterval FB_IS_SYSTEM_APP_CHECK_TIMEOUT_SEC = 5.;
// -terminate hard-asserts off the main thread, which may itself be busy - see -fb_terminate...:.
static const NSTimeInterval FB_APP_TERMINATE_TIMEOUT_SEC = 5.;
// How long a -kill caller that lost the race below waits for the winner's teardown to finish.
static const NSTimeInterval FB_KILL_WAIT_TIMEOUT_SEC = 35.;
NSString *const FBSessionWasKilledNotification = @"FBSessionWasKilledNotification";

@interface FBSession ()
@property (nullable, nonatomic) XCUIApplication *testedApplication;
@property (nonatomic) BOOL isTestedApplicationExpectedToRun;
@property (nonatomic) BOOL shouldAppsWaitForQuiescence;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, readwrite) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;

- (BOOL)fb_isTestedApplicationSameAsSystemAppWithTimeout:(NSTimeInterval)timeout;
- (void)fb_terminateTestedApplicationWithTimeout:(NSTimeInterval)timeout generation:(NSUInteger)generation;
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

// Guarded, together with the two counters below, by +teardownCondition.
static FBSession *_activeSession = nil;
// Class-level, not per-instance: a caller that finds _activeSession already nil (a concurrent
// -kill beat it there) still needs to know whether that -kill's teardown is done, since it cleared
// the pointer before running it. See +waitForActiveTeardownWithTimeout:.
// A count, not a flag: the bounded wait below lets teardowns overlap, so one of them finishing
// must not wake waiters while another still runs.
static NSUInteger _activeTeardownCount = 0;
// Bumped once a caller owns the device, before it launches anything; a teardown still running past
// the bounded wait re-checks it before touching process-wide state.
static NSUInteger _sessionGeneration = 0;
// Teardowns that have claimed the current generation and are committed to terminating the app.
// The generation bump waits for these to drain, so a claim and a bump can never interleave.
static NSUInteger _committedTerminationCount = 0;

+ (NSCondition *)teardownCondition
{
  static NSCondition *condition;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    condition = [NSCondition new];
  });
  return condition;
}

// Waits (bounded) for every -kill teardown currently in progress to finish.
+ (void)waitForActiveTeardownWithTimeout:(NSTimeInterval)timeout
{
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (_activeTeardownCount > 0 && [condition waitUntilDate:deadline]) {
  }
  [condition unlock];
}

+ (instancetype)activeSession
{
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  FBSession *session = _activeSession;
  [condition unlock];
  return session;
}

+ (void)killActiveSessionAndWaitForTeardown
{
  FBSession *session = self.activeSession;
  if (nil != session) {
    // Runs the real teardown synchronously if this call wins the race in -kill, or waits for
    // whoever did to finish if it lost - either way, blocks until torn down.
    [session kill];
  } else {
    // _activeSession is already nil, but a concurrent -kill (e.g. from DELETE /session) may still
    // be mid-teardown - wait for it, so we don't launch a replacement app too early.
    [self waitForActiveTeardownWithTimeout:FB_KILL_WAIT_TIMEOUT_SEC];
  }
  // Claimed before the caller launches its replacement app: if the bounded wait expired with a
  // teardown still running, that teardown must be stale by the time the new app exists.
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  // A committed -terminate cannot be revoked, so the next generation must never be handed out
  // while one is in flight - give up on the new session instead of racing it.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:FB_APP_TERMINATE_TIMEOUT_SEC];
  while (_committedTerminationCount > 0 && [condition waitUntilDate:deadline]) {
  }
  BOOL isTerminationPending = _committedTerminationCount > 0;
  if (!isTerminationPending) {
    _sessionGeneration++;
  }
  [condition unlock];
  if (isTerminationPending) {
    NSString *reason = [NSString stringWithFormat:@"The termination of a previous session's application is still in progress after %@ seconds. Please retry the session creation later", @(FB_APP_TERMINATE_TIMEOUT_SEC)];
    @throw [NSException exceptionWithName:FBSessionCreationException reason:reason userInfo:nil];
  }
}

+ (void)markSessionActive:(FBSession *)session
{
  [self killActiveSessionAndWaitForTeardown];
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  _activeSession = session;
  [condition unlock];
}

// Validates and claims `generation` in one critical section, so no replacement can be handed the
// next generation until the matching +endTermination. NO means this teardown is already stale.
+ (BOOL)beginTerminationForGeneration:(NSUInteger)generation
{
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  BOOL isCurrent = generation == _sessionGeneration;
  if (isCurrent) {
    _committedTerminationCount++;
  }
  [condition unlock];
  return isCurrent;
}

+ (void)endTermination
{
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  _committedTerminationCount--;
  [condition broadcast];
  [condition unlock];
}

// Read in the same critical section that validates the generation: a replacement would have bumped
// the generation before storing anything, so a promise captured here can never be its.
+ (FBScreenRecordingPromise *)activeScreenRecordingForGeneration:(NSUInteger)generation
{
  NSCondition *condition = self.teardownCondition;
  [condition lock];
  FBScreenRecordingPromise *promise = generation == _sessionGeneration
    ? FBScreenRecordingContainer.sharedInstance.screenRecordingPromise
    : nil;
  [condition unlock];
  return promise;
}

+ (instancetype)sessionWithIdentifier:(NSString *)identifier
{
  if (!identifier) {
    return nil;
  }
  // A single snapshot: reading the global twice could validate one session and return another.
  FBSession *session = self.activeSession;
  return [identifier isEqualToString:session.identifier] ? session : nil;
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
  // DELETE /session and session creation can now run concurrently, so a session already
  // superseded by a newer one can still reach here via a stale reference. Check-and-clear must be
  // atomic, else a belated -kill could null out the new session's pointer instead of its own.
  NSCondition *teardownCondition = self.class.teardownCondition;
  BOOL wasActive;
  NSUInteger generation;
  [teardownCondition lock];
  wasActive = (self == _activeSession);
  // Captured so the teardown steps below can tell whether a replacement has claimed the device.
  generation = _sessionGeneration;
  if (wasActive) {
    _activeSession = nil;
    // Registered in the same critical section as the clear above, else a concurrent session
    // creation could observe neither an active session nor a teardown and skip its wait.
    _activeTeardownCount++;
  }
  [teardownCondition unlock];
  if (!wasActive) {
    // Someone else is already tearing this session down - wait for that to finish (bounded), so
    // we don't act as if it's gone (e.g. launch a new app) while its -terminate is still in flight.
    [self.class waitForActiveTeardownWithTimeout:FB_KILL_WAIT_TIMEOUT_SEC];
    return;
  }

  @try {
    // Posted before teardown so pending HTTP requests for this session can stop waiting sooner.
    [NSNotificationCenter.defaultCenter postNotificationName:FBSessionWasKilledNotification object:self];

    [self disableAlertsMonitor];

    // The container is process-wide, so only act on a promise captured while this teardown still
    // owned the generation - nil here means it is stale and must leave the recording alone.
    FBScreenRecordingPromise *activeScreenRecording = [self.class activeScreenRecordingForGeneration:generation];
    if (nil != activeScreenRecording) {
      NSError *error;
      if (![FBXCTestDaemonsProxy stopScreenRecordingWithUUID:activeScreenRecording.identifier error:&error]) {
        [FBLogger logFmt:@"%@", error];
      }
      // Identity, not generation: the stop above may outlast a replacement storing its own promise.
      // Compare-and-reset, so that replacement's store cannot land between the check and the reset.
      [FBScreenRecordingContainer.sharedInstance resetIfPromiseIs:activeScreenRecording];
    }

    if (nil != self.testedApplication
        && FBConfiguration.sharedInstance.shouldTerminateApp
        && self.testedApplication.running
        && ![self fb_isTestedApplicationSameAsSystemAppWithTimeout:FB_IS_SYSTEM_APP_CHECK_TIMEOUT_SEC]) {
      // Blocks until the app is either actually terminated or durably given up on (never left
      // pending) - see -fb_terminateTestedApplicationWithTimeout:generation: - so it's safe to
      // report this teardown as finished as soon as this returns.
      [self fb_terminateTestedApplicationWithTimeout:FB_APP_TERMINATE_TIMEOUT_SEC generation:generation];
    }
  } @finally {
    [teardownCondition lock];
    _activeTeardownCount--;
    // Unconditional: waiters re-check the count, so a wake-up mid-teardown just puts them back.
    [teardownCondition broadcast];
    [teardownCondition unlock];
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

// Has no async variant and can block on the shared accessibility channel. Run off-thread and give
// up after `timeout`, assuming the tested app IS the system app - safer, since it means skipping
// termination rather than risking terminating springboard.
- (BOOL)fb_isTestedApplicationSameAsSystemAppWithTimeout:(NSTimeInterval)timeout
{
  __block XCUIApplication *systemApp = nil;
  __block NSException *caughtException = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    // Undocumented private API; guard in case it hard-asserts off-main like -terminate does on
    // some Xcode/iOS version - uncaught, that would crash the whole process.
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

// -terminate hard-asserts off-main, but -kill can now run on a background queue. Dispatching to
// main and waiting indefinitely could hang just as long as main is stuck, so give up after
// `timeout` - but a "given up on" call must never still terminate whatever's running by the time
// main gets to it (e.g. a replacement session's app), so cancellation and the actual terminate
// call share a lock: whichever gets there first - the dispatched block, or the timeout - wins.
- (void)fb_terminateTestedApplicationWithTimeout:(NSTimeInterval)timeout generation:(NSUInteger)generation
{
  XCUIApplication *application = self.testedApplication;
  NSObject *lock = [NSObject new];
  __block BOOL isAllowedToTerminate = YES;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_main_queue(), ^{
    @synchronized (lock) {
      // Re-checked here, not before dispatching: this block can sit on a busy main queue past the
      // teardown wait, and a replacement usually runs the same bundle ID as the app to terminate.
      // The claim is held across -terminate, so no replacement can take the next generation mid-call.
      if (isAllowedToTerminate && [self.class beginTerminationForGeneration:generation]) {
        @try {
          [application terminate];
        } @catch (NSException *e) {
          [FBLogger logFmt:@"%@", e.description];
        } @finally {
          [self.class endTermination];
        }
      }
    }
    dispatch_semaphore_signal(sem);
  });
  int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
  if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
    @synchronized (lock) {
      isAllowedToTerminate = NO;
    }
    [FBLogger logFmt:@"Could not terminate '%@' within %@ seconds; giving up on it rather than risk terminating a possible replacement session's app later", application.bundleID, @(timeout)];
  }
}

@end
