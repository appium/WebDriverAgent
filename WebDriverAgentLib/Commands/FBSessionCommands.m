/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSessionCommands.h"

#import "FBCapabilities.h"
#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBProtocolHelpers.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "FBSettings.h"
#import "FBSettingsHandler.h"
#import "FBRuntimeUtils.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIDevice.h"
#import "XCUIDevice+FBHealthCheck.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIApplicationProcessDelay.h"


@implementation FBSessionCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/url"] respondWithTarget:self action:@selector(handleOpenURL:)],
    [[FBRoute POST:@"/session"].withoutSession respondWithTarget:self action:@selector(handleCreateSession:)],
    [[FBRoute POST:@"/wda/apps/launch"] respondWithTarget:self action:@selector(handleSessionAppLaunch:)],
    [[FBRoute POST:@"/wda/apps/activate"] respondWithTarget:self action:@selector(handleSessionAppActivate:)],
    [[FBRoute POST:@"/wda/apps/terminate"] respondWithTarget:self action:@selector(handleSessionAppTerminate:)],
    [[FBRoute POST:@"/wda/apps/state"] respondWithTarget:self action:@selector(handleSessionAppState:)],
    [[FBRoute GET:@"/wda/apps/list"] respondWithTarget:self action:@selector(handleGetActiveAppsList:)],
    [[FBRoute GET:@""] respondWithTarget:self action:@selector(handleGetActiveSession:)],
    [[FBRoute DELETE:@""] respondWithTarget:self action:@selector(handleDeleteSession:)],
    [[FBRoute GET:@"/status"].withoutSession respondWithTarget:self action:@selector(handleGetStatus:)],

    // Health check might modify simulator state so it should only be called in-between testing sessions
    [[FBRoute GET:@"/wda/healthcheck"].withoutSession respondWithTarget:self action:@selector(handleGetHealthCheck:)],

    // Settings endpoints
    [[FBRoute GET:@"/appium/settings"] respondWithTarget:self action:@selector(handleGetSettings:)],
    [[FBRoute POST:@"/appium/settings"] respondWithTarget:self action:@selector(handleSetSettings:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleOpenURL:(FBRouteRequest *)request
{
  NSString *urlString = request.arguments[@"url"];
  if (!urlString) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"URL is required" traceback:nil]);
  }
  NSString* bundleId = request.arguments[@"bundleId"];
  NSNumber* idleTimeoutMs = request.arguments[@"idleTimeoutMs"];
  NSError *error;
  if (nil == bundleId) {
    if (![XCUIDevice.sharedDevice fb_openUrl:urlString error:&error]) {
      return FBResponseWithUnknownError(error);
    }
  } else {
    if (![XCUIDevice.sharedDevice fb_openUrl:urlString withApplication:bundleId error:&error]) {
      return FBResponseWithUnknownError(error);
    }
    if (idleTimeoutMs.doubleValue > 0) {
      XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:bundleId];
      [app fb_waitUntilStableWithTimeout:FBMillisToSeconds(idleTimeoutMs.doubleValue)];
    }
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleCreateSession:(FBRouteRequest *)request
{
  if (nil != FBSession.activeSession) {
    [FBSession.activeSession kill];
  }

  NSDictionary<NSString *, id> *capabilities;
  id<FBResponsePayload> errorResponse = [self capabilitiesFromCreateSessionRequest:request
                                                                    capabilitiesOut:&capabilities];
  if (nil != errorResponse) {
    return errorResponse;
  }

  [self applyConfigurationFromCapabilities:capabilities];

  NSString *bundleID = capabilities[FB_CAP_BUNDLE_ID];
  NSString *initialUrl = capabilities[FB_CAP_INITIAL_URL];
  XCUIApplication *app = nil;
  errorResponse = [self prepareApplicationForSessionWithBundleID:bundleID
                                                      initialUrl:initialUrl
                                                    capabilities:capabilities
                                                     application:&app];
  if (nil != errorResponse) {
    return errorResponse;
  }

  if (nil != initialUrl && nil == bundleID) {
    errorResponse = [self openDeepLink:initialUrl
                       withApplication:nil
                               timeout:capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC]];
    if (nil != errorResponse) {
      return errorResponse;
    }
  }

  [self initializeSessionWithApplication:app capabilities:capabilities];

  return FBResponseWithObject(FBSessionCommands.sessionInformation);
}

+ (id<FBResponsePayload>)handleSessionAppLaunch:(FBRouteRequest *)request
{
  [request.session launchApplicationWithBundleId:(id)request.arguments[@"bundleId"]
                         shouldWaitForQuiescence:request.arguments[@"shouldWaitForQuiescence"]
                                       arguments:request.arguments[@"arguments"]
                                     environment:request.arguments[@"environment"]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSessionAppActivate:(FBRouteRequest *)request
{
  [request.session activateApplicationWithBundleId:(id)request.arguments[@"bundleId"]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSessionAppTerminate:(FBRouteRequest *)request
{
  BOOL result = [request.session terminateApplicationWithBundleId:(id)request.arguments[@"bundleId"]];
  return FBResponseWithObject(@(result));
}

+ (id<FBResponsePayload>)handleSessionAppState:(FBRouteRequest *)request
{
  NSUInteger state = [request.session applicationStateWithBundleId:(id)request.arguments[@"bundleId"]];
  return FBResponseWithObject(@(state));
}

+ (id<FBResponsePayload>)handleGetActiveAppsList:(FBRouteRequest *)request
{
  return FBResponseWithObject([XCUIApplication fb_activeAppsInfo]);
}

+ (id<FBResponsePayload>)handleGetActiveSession:(FBRouteRequest *)request
{
  return FBResponseWithObject(FBSessionCommands.sessionInformation);
}

+ (id<FBResponsePayload>)handleDeleteSession:(FBRouteRequest *)request
{
  [request.session kill];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetStatus:(FBRouteRequest *)request
{
  // For updatedWDABundleId capability by Appium
  NSString *productBundleIdentifier = @"com.facebook.WebDriverAgentRunner";
  NSString *envproductBundleIdentifier = NSProcessInfo.processInfo.environment[@"WDA_PRODUCT_BUNDLE_IDENTIFIER"];
  if (envproductBundleIdentifier && [envproductBundleIdentifier length] != 0) {
    productBundleIdentifier = NSProcessInfo.processInfo.environment[@"WDA_PRODUCT_BUNDLE_IDENTIFIER"];
  }

  NSMutableDictionary *buildInfo = [NSMutableDictionary dictionaryWithDictionary:@{
    @"time" : [self.class buildTimestamp],
    @"productBundleIdentifier" : productBundleIdentifier,
  }];
  NSString *upgradeTimestamp = NSProcessInfo.processInfo.environment[@"UPGRADE_TIMESTAMP"];
  if (nil != upgradeTimestamp && upgradeTimestamp.length > 0) {
    [buildInfo setObject:upgradeTimestamp forKey:@"upgradedAt"];
  }
  NSDictionary *infoDict = [[NSBundle bundleForClass:self.class] infoDictionary];
  NSString *version = [infoDict objectForKey:@"CFBundleShortVersionString"];
  if (nil != version) {
    [buildInfo setObject:version forKey:@"version"];
  }

  return FBResponseWithObject(
    @{
      @"ready" : @YES,
      @"message" : @"WebDriverAgent is ready to accept commands",
      @"state" : @"success",
      @"os" :
        @{
          @"name" : [[UIDevice currentDevice] systemName],
          @"version" : [[UIDevice currentDevice] systemVersion],
          @"sdkVersion": FBSDKVersion() ?: @"unknown",
          @"testmanagerdVersion": @(FBTestmanagerdVersion()),
        },
      @"ios" :
        @{
#if TARGET_OS_SIMULATOR
          @"simulatorVersion" : [[UIDevice currentDevice] systemVersion],
#endif
          @"ip" : [XCUIDevice sharedDevice].fb_wifiIPAddress ?: [NSNull null]
        },
      @"build" : buildInfo.copy,
      @"device": [self.class deviceNameByUserInterfaceIdiom:[UIDevice currentDevice].userInterfaceIdiom]
    }
  );
}

+ (id<FBResponsePayload>)handleGetHealthCheck:(FBRouteRequest *)request
{
  if (![[XCUIDevice sharedDevice] fb_healthCheckWithApplication:[XCUIApplication fb_activeApplication]]) {
    return FBResponseWithUnknownErrorFormat(@"Health check failed");
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetSettings:(FBRouteRequest *)request
{
  return FBResponseWithObject([FBSettingsHandler currentSettingsForSession:request.session]);
}

+ (id<FBResponsePayload>)handleSetSettings:(FBRouteRequest *)request
{
  id settingsArgument = request.arguments[@"settings"];
  if (nil != settingsArgument && ![settingsArgument isKindOfClass:NSDictionary.class]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"settings must be a dictionary"
                                                                       traceback:nil]);
  }
  NSDictionary *settings = settingsArgument ?: @{};
  FBCommandStatus *status = [FBSettingsHandler applySettings:settings
                                                   toSession:request.session];
  if (status.hasError) {
    return FBResponseWithStatus(status);
  }
  return [self handleGetSettings:request];
}


#pragma mark - Session Creation Helpers

+ (nullable id<FBResponsePayload>)capabilitiesFromCreateSessionRequest:(FBRouteRequest *)request
                                                         capabilitiesOut:(NSDictionary<NSString *, id> *_Nonnull *_Nonnull)capabilitiesOut
{
  if (![request.arguments[@"capabilities"] isKindOfClass:NSDictionary.class]) {
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:@"'capabilities' is mandatory to create a new session"
                                                              traceback:nil]);
  }
  NSError *error;
  NSDictionary<NSString *, id> *capabilities = FBParseCapabilities((NSDictionary *)request.arguments[@"capabilities"], &error);
  if (nil == capabilities) {
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:error.localizedDescription traceback:nil]);
  }
  *capabilitiesOut = capabilities;
  return nil;
}

+ (void)applyConfigurationFromCapabilities:(NSDictionary<NSString *, id> *)capabilities
{
  [FBConfiguration resetSessionSettings];
  if (capabilities[FB_SETTING_USE_COMPACT_RESPONSES]) {
    [FBConfiguration setShouldUseCompactResponses:[capabilities[FB_SETTING_USE_COMPACT_RESPONSES] boolValue]];
  }
  NSString *elementResponseAttributes = capabilities[FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES];
  if (elementResponseAttributes) {
    [FBConfiguration setElementResponseAttributes:elementResponseAttributes];
  }
  if (capabilities[FB_CAP_MAX_TYPING_FREQUENCY]) {
    [FBConfiguration setMaxTypingFrequency:[capabilities[FB_CAP_MAX_TYPING_FREQUENCY] unsignedIntegerValue]];
  }
  if (capabilities[FB_CAP_USE_SINGLETON_TEST_MANAGER]) {
    [FBConfiguration setShouldUseSingletonTestManager:[capabilities[FB_CAP_USE_SINGLETON_TEST_MANAGER] boolValue]];
  }
  if (capabilities[FB_CAP_DISABLE_AUTOMATIC_SCREENSHOTS]) {
    if ([capabilities[FB_CAP_DISABLE_AUTOMATIC_SCREENSHOTS] boolValue]) {
      [FBConfiguration disableScreenshots];
    } else {
      [FBConfiguration enableScreenshots];
    }
  }
  if (capabilities[FB_CAP_SHOULD_TERMINATE_APP]) {
    [FBConfiguration setShouldTerminateApp:[capabilities[FB_CAP_SHOULD_TERMINATE_APP] boolValue]];
  }
  NSNumber *delay = capabilities[FB_CAP_EVENT_LOOP_IDLE_DELAY_SEC];
  if ([delay doubleValue] > 0.0) {
    [XCUIApplicationProcessDelay setEventLoopHasIdledDelay:[delay doubleValue]];
  } else {
    [XCUIApplicationProcessDelay disableEventLoopDelay];
  }
  if (nil != capabilities[FB_SETTING_WAIT_FOR_IDLE_TIMEOUT]) {
    FBConfiguration.waitForIdleTimeout = [capabilities[FB_SETTING_WAIT_FOR_IDLE_TIMEOUT] doubleValue];
  }
  if (nil == capabilities[FB_CAP_FORCE_SIMULATOR_SOFTWARE_KEYBOARD_PRESENCE] ||
      [capabilities[FB_CAP_FORCE_SIMULATOR_SOFTWARE_KEYBOARD_PRESENCE] boolValue]) {
    [FBConfiguration forceSimulatorSoftwareKeyboardPresence];
  }
}

+ (nullable id<FBResponsePayload>)prepareApplicationForSessionWithBundleID:(nullable NSString *)bundleID
                                                                initialUrl:(nullable NSString *)initialUrl
                                                            capabilities:(NSDictionary<NSString *, id> *)capabilities
                                                             application:(XCUIApplication *_Nullable *_Nonnull)applicationOut
{
  if (nil == bundleID) {
    *applicationOut = nil;
    return nil;
  }

  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:bundleID];
  BOOL forceAppLaunch = nil == capabilities[FB_CAP_FORCE_APP_LAUNCH]
    || [capabilities[FB_CAP_FORCE_APP_LAUNCH] boolValue];
  XCUIApplicationState appState = app.state;
  BOOL isAppRunning = appState >= XCUIApplicationStateRunningBackground;

  if (!isAppRunning || (isAppRunning && forceAppLaunch)) {
    id<FBResponsePayload> errorResponse = [self launchApplication:app
                                                         bundleID:bundleID
                                                       initialUrl:initialUrl
                                                     capabilities:capabilities];
    if (nil != errorResponse) {
      return errorResponse;
    }
  } else if (appState == XCUIApplicationStateRunningBackground && !forceAppLaunch) {
    id<FBResponsePayload> errorResponse = [self activateBackgroundApplication:app
                                                                     bundleID:bundleID
                                                                   initialUrl:initialUrl];
    if (nil != errorResponse) {
      return errorResponse;
    }
  }

  *applicationOut = app;
  return nil;
}

+ (nullable id<FBResponsePayload>)launchApplication:(XCUIApplication *)app
                                           bundleID:(NSString *)bundleID
                                         initialUrl:(nullable NSString *)initialUrl
                                       capabilities:(NSDictionary<NSString *, id> *)capabilities
{
  app.fb_shouldWaitForQuiescence = nil == capabilities[FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE]
    || [capabilities[FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE] boolValue];
  app.launchArguments = (NSArray<NSString *> *)capabilities[FB_CAP_ARGUMENTS] ?: @[];
  app.launchEnvironment = (NSDictionary<NSString *, NSString *> *)capabilities[FB_CAP_ENVIRNOMENT] ?: @{};

  if (nil != initialUrl) {
    if (app.running) {
      [app terminate];
    }
    id<FBResponsePayload> errorResponse = [self openDeepLink:initialUrl
                                               withApplication:bundleID
                                                       timeout:capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC]];
    if (nil != errorResponse) {
      return errorResponse;
    }
  } else {
    NSTimeInterval defaultTimeout = _XCTApplicationStateTimeout();
    if (nil != capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC]) {
      _XCTSetApplicationStateTimeout([capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC] doubleValue]);
    }
    @try {
      [app launch];
    } @catch (NSException *e) {
      return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:e.reason traceback:nil]);
    } @finally {
      if (nil != capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC]) {
        _XCTSetApplicationStateTimeout(defaultTimeout);
      }
    }
  }

  if (!app.running) {
    NSString *errorMsg = [NSString stringWithFormat:@"Cannot launch %@ application. Make sure the correct bundle identifier has been provided in capabilities and check the device log for possible crash report occurrences", bundleID];
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:errorMsg traceback:nil]);
  }
  return nil;
}

+ (nullable id<FBResponsePayload>)activateBackgroundApplication:(XCUIApplication *)app
                                                       bundleID:(NSString *)bundleID
                                                     initialUrl:(nullable NSString *)initialUrl
{
  if (nil != initialUrl) {
    return [self openDeepLink:initialUrl withApplication:bundleID timeout:nil];
  }
  [app activate];
  return nil;
}

+ (void)initializeSessionWithApplication:(nullable XCUIApplication *)app
                          capabilities:(NSDictionary<NSString *, id> *)capabilities
{
  if (capabilities[FB_SETTING_DEFAULT_ALERT_ACTION]) {
    [FBSession initWithApplication:app
                defaultAlertAction:(id)capabilities[FB_SETTING_DEFAULT_ALERT_ACTION]];
  } else {
    [FBSession initWithApplication:app];
  }
  if (nil != capabilities[FB_CAP_USE_NATIVE_CACHING_STRATEGY]) {
    FBSession.activeSession.useNativeCachingStrategy = [capabilities[FB_CAP_USE_NATIVE_CACHING_STRATEGY] boolValue];
  }
}

#pragma mark - Helpers

+ (NSString *)buildTimestamp
{
  return [NSString stringWithFormat:@"%@ %@",
    [NSString stringWithUTF8String:__DATE__],
    [NSString stringWithUTF8String:__TIME__]
  ];
}

/**
 Return current session information.
 This response does not have any active application information.
*/
+ (NSDictionary *)sessionInformation
{
  return
  @{
    @"sessionId" : [FBSession activeSession].identifier ?: NSNull.null,
    @"capabilities" : FBSessionCommands.currentCapabilities
  };
}

/*
 Return the device kind as lower case
*/
+ (NSString *)deviceNameByUserInterfaceIdiom:(UIUserInterfaceIdiom) userInterfaceIdiom
{
  if (userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    return @"ipad";
  } else if (userInterfaceIdiom == UIUserInterfaceIdiomTV) {
    return @"apple tv";
  } else if (userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
    return @"iphone";
  }
  // CarPlay, Mac, Vision UI or unknown are possible
  return @"Unknown";

}

+ (NSDictionary *)currentCapabilities
{
  return
  @{
    @"device": [self.class deviceNameByUserInterfaceIdiom:[UIDevice currentDevice].userInterfaceIdiom],
    @"sdkVersion": [[UIDevice currentDevice] systemVersion]
  };
}

+(nullable id<FBResponsePayload>)openDeepLink:(NSString *)initialUrl
                              withApplication:(nullable NSString *)bundleID
                                      timeout:(nullable NSNumber *)timeout
{
  NSError *openError;
  NSTimeInterval defaultTimeout = _XCTApplicationStateTimeout();
  if (nil != timeout) {
    _XCTSetApplicationStateTimeout([timeout doubleValue]);
  }
  @try {
    BOOL result = nil == bundleID
      ? [XCUIDevice.sharedDevice fb_openUrl:initialUrl
                                      error:&openError]
      : [XCUIDevice.sharedDevice fb_openUrl:initialUrl
                            withApplication:(id)bundleID
                                      error:&openError];
    if (result) {
      return nil;
    }
    NSString *errorMsg = [NSString stringWithFormat:@"Cannot open the URL %@ with the %@ application. Original error: %@",
                          initialUrl, bundleID ?: @"default", openError.localizedDescription];
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:errorMsg traceback:nil]);
  } @finally {
    if (nil != timeout) {
      _XCTSetApplicationStateTimeout(defaultTimeout);
    }
  }
}

@end
