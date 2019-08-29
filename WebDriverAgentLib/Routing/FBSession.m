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

#import "FBAlertsMonitor.h"
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBElementCache.h"
#import "FBMacros.h"
#import "FBSpringboardApplication.h"
#import "FBXCodeCompatibility.h"
#import "XCAccessibilityElement.h"
#import "XCUIElement.h"

NSString *const FBApplicationCrashedException = @"FBApplicationCrashedException";
/*!
 The intial value for the default application property.
 Setting this value to `defaultActiveApplication` property forces WDA to use the internal
 automated algorithm to determine the active on-screen application
 */
NSString *const FBDefaultApplicationAuto = @"auto";

@interface FBSession ()
@property (nonatomic) NSString *testedApplicationBundleId;
@property (nonatomic) NSDictionary<NSString *, FBApplication *> *applications;
@property (nonatomic, strong, readwrite) FBApplication *testedApplication;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, nullable) NSString *defaultAlertAction;
@end

@interface FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert;

@end

@implementation FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert
{
  if (nil == self.defaultAlertAction) {
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

static FBSession *_activeSession;
+ (instancetype)activeSession
{
  return _activeSession ?: [FBSession initWithApplication:nil];
}

+ (void)markSessionActive:(FBSession *)session
{
  if (_activeSession && _activeSession.testedApplication.bundleID != session.testedApplication.bundleID) {
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

+ (instancetype)initWithApplication:(FBApplication *)application
{
  FBSession *session = [FBSession new];
  session.alertsMonitor = nil;
  session.defaultAlertAction = nil;
  session.identifier = [[NSUUID UUID] UUIDString];
  session.defaultActiveApplication = FBDefaultApplicationAuto;
  session.testedApplicationBundleId = nil;
  NSMutableDictionary *apps = [NSMutableDictionary dictionary];
  if (application) {
    [apps setObject:application forKey:application.bundleID];
    session.testedApplicationBundleId = application.bundleID;
  }
  session.applications = apps.copy;
  session.elementCache = [FBElementCache new];
  [FBSession markSessionActive:session];
  return session;
}

+ (instancetype)initWithApplication:(nullable FBApplication *)application defaultAlertAction:(NSString *)defaultAlertAction
{
  FBSession *session = [self.class initWithApplication:application];
  session.alertsMonitor = [[FBAlertsMonitor alloc] init];
  session.alertsMonitor.delegate = (id<FBAlertsMonitorDelegate>)session;
  session.alertsMonitor.application = application;
  session.defaultAlertAction = [defaultAlertAction lowercaseString];
  [session.alertsMonitor enable];
  return session;
}

- (void)kill
{
  if (nil != self.alertsMonitor) {
    [self.alertsMonitor disable];
    self.alertsMonitor = nil;
  }

  if (self.testedApplicationBundleId) {
    [[self.applications objectForKey:self.testedApplicationBundleId] terminate];
  }
  _activeSession = nil;
}

- (FBApplication *)activeApplication
{
  NSString *defaultBundleId = [self.defaultActiveApplication isEqualToString:FBDefaultApplicationAuto]
    ? nil
    : self.defaultActiveApplication;
  FBApplication *application = [FBApplication fb_activeApplicationWithDefaultBundleId:defaultBundleId];
  FBApplication *testedApplication = nil;
  if (self.testedApplicationBundleId) {
    testedApplication = [self.applications objectForKey:self.testedApplicationBundleId];
  }
  if (testedApplication && !testedApplication.running) {
    NSString *description = [NSString stringWithFormat:@"The application under test with bundle id '%@' is not running, possibly crashed", self.testedApplicationBundleId];
    [[NSException exceptionWithName:FBApplicationCrashedException reason:description userInfo:nil] raise];
  }
  if (nil != self.alertsMonitor) {
    self.alertsMonitor.application = application;
  }
  return application;
}

- (FBApplication *)registerApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [self.applications objectForKey:bundleIdentifier];
  if (!app) {
    app = [[FBApplication alloc] initPrivateWithPath:nil bundleID:bundleIdentifier];
    NSMutableDictionary *apps = self.applications.mutableCopy;
    [apps setObject:app forKey:bundleIdentifier];
    self.applications = apps.copy;
  }
  return app;
}

- (BOOL)unregisterApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [self.applications objectForKey:bundleIdentifier];
  if (app) {
    NSMutableDictionary *apps = self.applications.mutableCopy;
    [apps removeObjectForKey:bundleIdentifier];
    self.applications = apps.copy;
    return YES;
  }
  return NO;
}

- (void)launchApplicationWithBundleId:(NSString *)bundleIdentifier
              shouldWaitForQuiescence:(nullable NSNumber *)shouldWaitForQuiescence
                            arguments:(nullable NSArray<NSString *> *)arguments
                          environment:(nullable NSDictionary <NSString *, NSString *> *)environment
{
  FBApplication *app = [self registerApplicationWithBundleId:bundleIdentifier];
  if (app.fb_state < 2) {
    if (nil != shouldWaitForQuiescence) {
      app.fb_shouldWaitForQuiescence = [shouldWaitForQuiescence boolValue];
    } else if ([bundleIdentifier isEqualToString:self.testedApplicationBundleId]) {
      app.fb_shouldWaitForQuiescence = FBConfiguration.shouldWaitForQuiescence;
    }
    app.launchArguments = arguments ?: @[];
    app.launchEnvironment = environment ?: @{};
    [app launch];
  } else {
    [app fb_activate];
  }
}

- (void)activateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [self registerApplicationWithBundleId:bundleIdentifier];
  [app fb_activate];
}

- (BOOL)terminateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [self registerApplicationWithBundleId:bundleIdentifier];
  BOOL result = NO;
  if (app.fb_state >= 2) {
    [app terminate];
    result = YES;
  }
  [self unregisterApplicationWithBundleId:bundleIdentifier];
  return result;
}

- (NSUInteger)applicationStateWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [self.applications objectForKey:bundleIdentifier];
  if (!app) {
    app = [[FBApplication alloc] initPrivateWithPath:nil bundleID:bundleIdentifier];
  }
  return app.fb_state;
}

@end
