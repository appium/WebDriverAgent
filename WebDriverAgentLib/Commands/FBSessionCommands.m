/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSessionCommands.h"

#import "FBCapabilities.h"
#import "FBClassChainQueryParser.h"
#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBProtocolHelpers.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "FBSettings.h"
#import "FBRuntimeUtils.h"
#import "FBActiveAppDetectionPoint.h"
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
  NSError *error;
  if (![request.arguments[@"capabilities"] isKindOfClass:NSDictionary.class]) {
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:@"'capabilities' is mandatory to create a new session"
                                                              traceback:nil]);
  }
  if (nil == (capabilities = FBParseCapabilities((NSDictionary *)request.arguments[@"capabilities"], &error))) {
    return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:error.localizedDescription traceback:nil]);
  }

  [FBConfiguration resetSessionSettings];
  [FBConfiguration setShouldUseTestManagerForVisibilityDetection:[capabilities[FB_CAP_USE_TEST_MANAGER_FOR_VISIBLITY_DETECTION] boolValue]];
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

  NSString *bundleID = capabilities[FB_CAP_BUNDLE_ID];
  NSString *initialUrl = capabilities[FB_CAP_INITIAL_URL];
  XCUIApplication *app = nil;
  if (bundleID != nil) {
    app = [[XCUIApplication alloc] initWithBundleIdentifier:bundleID];
    BOOL forceAppLaunch = YES;
    if (nil != capabilities[FB_CAP_FORCE_APP_LAUNCH]) {
      forceAppLaunch = [capabilities[FB_CAP_FORCE_APP_LAUNCH] boolValue];
    }
    XCUIApplicationState appState = app.state;
    BOOL isAppRunning = appState >= XCUIApplicationStateRunningBackground;
    if (!isAppRunning || (isAppRunning && forceAppLaunch)) {
      app.fb_shouldWaitForQuiescence = nil == capabilities[FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE]
        || [capabilities[FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE] boolValue];
      app.launchArguments = (NSArray<NSString *> *)capabilities[FB_CAP_ARGUMENTS] ?: @[];
      app.launchEnvironment = (NSDictionary <NSString *, NSString *> *)capabilities[FB_CAP_ENVIRNOMENT] ?: @{};
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
        return FBResponseWithStatus([FBCommandStatus sessionNotCreatedError:errorMsg
                                                                  traceback:nil]);
      }
    } else if (appState == XCUIApplicationStateRunningBackground && !forceAppLaunch) {
      if (nil != initialUrl) {
        id<FBResponsePayload> errorResponse = [self openDeepLink:initialUrl
                                                 withApplication:bundleID
                                                         timeout:nil];
        if (nil != errorResponse) {
          return errorResponse;
        }
      } else {
        [app activate];
      }
    }
  }

  if (nil != initialUrl && nil == bundleID) {
    id<FBResponsePayload> errorResponse = [self openDeepLink:initialUrl
                                             withApplication:nil
                                                     timeout:capabilities[FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC]];
    if (nil != errorResponse) {
      return errorResponse;
    }
  }

  if (capabilities[FB_SETTING_DEFAULT_ALERT_ACTION]) {
    [FBSession initWithApplication:app
                defaultAlertAction:(id)capabilities[FB_SETTING_DEFAULT_ALERT_ACTION]];
  } else {
    [FBSession initWithApplication:app];
  }

  if (nil != capabilities[FB_CAP_USE_NATIVE_CACHING_STRATEGY]) {
    FBSession.activeSession.useNativeCachingStrategy = [capabilities[FB_CAP_USE_NATIVE_CACHING_STRATEGY] boolValue];
  }

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
  return FBResponseWithObject(
    @{
      FB_SETTING_USE_COMPACT_RESPONSES: @([FBConfiguration shouldUseCompactResponses]),
      FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES: [FBConfiguration elementResponseAttributes],
      FB_SETTING_MJPEG_SERVER_SCREENSHOT_QUALITY: @([FBConfiguration mjpegServerScreenshotQuality]),
      FB_SETTING_MJPEG_SERVER_FRAMERATE: @([FBConfiguration mjpegServerFramerate]),
      FB_SETTING_MJPEG_SCALING_FACTOR: @([FBConfiguration mjpegScalingFactor]),
      FB_SETTING_MJPEG_FIX_ORIENTATION: @([FBConfiguration mjpegShouldFixOrientation]),
      FB_SETTING_SCREENSHOT_QUALITY: @([FBConfiguration screenshotQuality]),
      FB_SETTING_KEYBOARD_AUTOCORRECTION: @([FBConfiguration keyboardAutocorrection]),
      FB_SETTING_KEYBOARD_PREDICTION: @([FBConfiguration keyboardPrediction]),
      FB_SETTING_SNAPSHOT_MAX_DEPTH: @([FBConfiguration snapshotMaxDepth]),
      FB_SETTING_USE_FIRST_MATCH: @([FBConfiguration useFirstMatch]),
      FB_SETTING_WAIT_FOR_IDLE_TIMEOUT: @([FBConfiguration waitForIdleTimeout]),
      FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT: @([FBConfiguration animationCoolOffTimeout]),
      FB_SETTING_BOUND_ELEMENTS_BY_INDEX: @([FBConfiguration boundElementsByIndex]),
      FB_SETTING_REDUCE_MOTION: @([FBConfiguration reduceMotionEnabled]),
      FB_SETTING_DEFAULT_ACTIVE_APPLICATION: request.session.defaultActiveApplication,
      FB_SETTING_ACTIVE_APP_DETECTION_POINT: FBActiveAppDetectionPoint.sharedInstance.stringCoordinates,
      FB_SETTING_INCLUDE_NON_MODAL_ELEMENTS: @([FBConfiguration includeNonModalElements]),
      FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR: FBConfiguration.acceptAlertButtonSelector,
      FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR: FBConfiguration.dismissAlertButtonSelector,
      FB_SETTING_AUTO_CLICK_ALERT_SELECTOR: FBConfiguration.autoClickAlertSelector,
      FB_SETTING_DEFAULT_ALERT_ACTION: request.session.defaultAlertAction ?: @"",
      FB_SETTING_MAX_TYPING_FREQUENCY: @([FBConfiguration maxTypingFrequency]),
      FB_SETTING_RESPECT_SYSTEM_ALERTS: @([FBConfiguration shouldRespectSystemAlerts]),
      FB_SETTING_USE_CLEAR_TEXT_SHORTCUT: @([FBConfiguration useClearTextShortcut]),
      FB_SETTING_INCLUDE_HITTABLE_IN_PAGE_SOURCE: @([FBConfiguration includeHittableInPageSource]),
      FB_SETTING_INCLUDE_NATIVE_FRAME_IN_PAGE_SOURCE: @([FBConfiguration includeNativeFrameInPageSource]),
      FB_SETTING_INCLUDE_PLACEHOLDER_VALUE_IN_PAGE_SOURCE: @([FBConfiguration includePlaceholderValueInPageSource]),
      FB_SETTING_INCLUDE_MIN_MAX_VALUE_IN_PAGE_SOURCE: @([FBConfiguration includeMinMaxValueInPageSource]),
      FB_SETTING_LIMIT_XPATH_CONTEXT_SCOPE: @([FBConfiguration limitXpathContextScope]),
#if !TARGET_OS_TV
      FB_SETTING_SCREENSHOT_ORIENTATION: [FBConfiguration humanReadableScreenshotOrientation],
#endif
    }
  );
}

// TODO if we get lots more settings, handling them with a series of if-statements will be unwieldy
// and this should be refactored
+ (id<FBResponsePayload>)handleSetSettings:(FBRouteRequest *)request
{
  NSDictionary* settings = request.arguments[@"settings"];

  if (nil != [settings objectForKey:FB_SETTING_USE_COMPACT_RESPONSES]) {
    [FBConfiguration setShouldUseCompactResponses:[[settings objectForKey:FB_SETTING_USE_COMPACT_RESPONSES] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES]) {
    [FBConfiguration setElementResponseAttributes:(NSString *)[settings objectForKey:FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES]];
  }
  if (nil != [settings objectForKey:FB_SETTING_MJPEG_SERVER_SCREENSHOT_QUALITY]) {
    [FBConfiguration setMjpegServerScreenshotQuality:[[settings objectForKey:FB_SETTING_MJPEG_SERVER_SCREENSHOT_QUALITY] unsignedIntegerValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_MJPEG_SERVER_FRAMERATE]) {
    [FBConfiguration setMjpegServerFramerate:[[settings objectForKey:FB_SETTING_MJPEG_SERVER_FRAMERATE] unsignedIntegerValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_SCREENSHOT_QUALITY]) {
    [FBConfiguration setScreenshotQuality:[[settings objectForKey:FB_SETTING_SCREENSHOT_QUALITY] unsignedIntegerValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_MJPEG_SCALING_FACTOR]) {
    [FBConfiguration setMjpegScalingFactor:[[settings objectForKey:FB_SETTING_MJPEG_SCALING_FACTOR] floatValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_MJPEG_FIX_ORIENTATION]) {
    [FBConfiguration setMjpegShouldFixOrientation:[[settings objectForKey:FB_SETTING_MJPEG_FIX_ORIENTATION] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_KEYBOARD_AUTOCORRECTION]) {
    [FBConfiguration setKeyboardAutocorrection:[[settings objectForKey:FB_SETTING_KEYBOARD_AUTOCORRECTION] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_KEYBOARD_PREDICTION]) {
    [FBConfiguration setKeyboardPrediction:[[settings objectForKey:FB_SETTING_KEYBOARD_PREDICTION] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_RESPECT_SYSTEM_ALERTS]) {
    [FBConfiguration setShouldRespectSystemAlerts:[[settings objectForKey:FB_SETTING_RESPECT_SYSTEM_ALERTS] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_SNAPSHOT_MAX_DEPTH]) {
    [FBConfiguration setSnapshotMaxDepth:[[settings objectForKey:FB_SETTING_SNAPSHOT_MAX_DEPTH] intValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_USE_FIRST_MATCH]) {
    [FBConfiguration setUseFirstMatch:[[settings objectForKey:FB_SETTING_USE_FIRST_MATCH] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_BOUND_ELEMENTS_BY_INDEX]) {
    [FBConfiguration setBoundElementsByIndex:[[settings objectForKey:FB_SETTING_BOUND_ELEMENTS_BY_INDEX] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_REDUCE_MOTION]) {
    [FBConfiguration setReduceMotionEnabled:[[settings objectForKey:FB_SETTING_REDUCE_MOTION] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_DEFAULT_ACTIVE_APPLICATION]) {
    request.session.defaultActiveApplication = (NSString *)[settings objectForKey:FB_SETTING_DEFAULT_ACTIVE_APPLICATION];
  }
  if (nil != [settings objectForKey:FB_SETTING_ACTIVE_APP_DETECTION_POINT]) {
    NSError *error;
    if (![FBActiveAppDetectionPoint.sharedInstance setCoordinatesWithString:(NSString *)[settings objectForKey:FB_SETTING_ACTIVE_APP_DETECTION_POINT]
                                                                      error:&error]) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                         traceback:nil]);
    }
  }
  if (nil != [settings objectForKey:FB_SETTING_INCLUDE_NON_MODAL_ELEMENTS]) {
    if ([XCUIElement fb_supportsNonModalElementsInclusion]) {
      [FBConfiguration setIncludeNonModalElements:[[settings objectForKey:FB_SETTING_INCLUDE_NON_MODAL_ELEMENTS] boolValue]];
    } else {
      [FBLogger logFmt:@"'%@' settings value cannot be assigned, because non modal elements inclusion is not supported by the current iOS SDK", FB_SETTING_INCLUDE_NON_MODAL_ELEMENTS];
    }
  }
  if (nil != [settings objectForKey:FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR]) {
    [FBConfiguration setAcceptAlertButtonSelector:(NSString *)[settings objectForKey:FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR]];
  }
  if (nil != [settings objectForKey:FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR]) {
    [FBConfiguration setDismissAlertButtonSelector:(NSString *)[settings objectForKey:FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR]];
  }
  if (nil != [settings objectForKey:FB_SETTING_AUTO_CLICK_ALERT_SELECTOR]) {
    FBCommandStatus *status = [self.class configureAutoClickAlertWithSelector:settings[FB_SETTING_AUTO_CLICK_ALERT_SELECTOR]
                                                                   forSession:request.session];
    if (status.hasError) {
      return FBResponseWithStatus(status);
    }
  }
  if (nil != [settings objectForKey:FB_SETTING_WAIT_FOR_IDLE_TIMEOUT]) {
    [FBConfiguration setWaitForIdleTimeout:[[settings objectForKey:FB_SETTING_WAIT_FOR_IDLE_TIMEOUT] doubleValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT]) {
    [FBConfiguration setAnimationCoolOffTimeout:[[settings objectForKey:FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT] doubleValue]];
  }
  if ([[settings objectForKey:FB_SETTING_DEFAULT_ALERT_ACTION] isKindOfClass:NSString.class]) {
    request.session.defaultAlertAction = [settings[FB_SETTING_DEFAULT_ALERT_ACTION] lowercaseString];
  }
  if (nil != [settings objectForKey:FB_SETTING_MAX_TYPING_FREQUENCY]) {
    [FBConfiguration setMaxTypingFrequency:[[settings objectForKey:FB_SETTING_MAX_TYPING_FREQUENCY] unsignedIntegerValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_USE_CLEAR_TEXT_SHORTCUT]) {
    [FBConfiguration setUseClearTextShortcut:[[settings objectForKey:FB_SETTING_USE_CLEAR_TEXT_SHORTCUT] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_INCLUDE_HITTABLE_IN_PAGE_SOURCE]) {
    [FBConfiguration setIncludeHittableInPageSource:[[settings objectForKey:FB_SETTING_INCLUDE_HITTABLE_IN_PAGE_SOURCE] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_INCLUDE_NATIVE_FRAME_IN_PAGE_SOURCE]) {
    [FBConfiguration setIncludeNativeFrameInPageSource:[[settings objectForKey:FB_SETTING_INCLUDE_NATIVE_FRAME_IN_PAGE_SOURCE] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_INCLUDE_PLACEHOLDER_VALUE_IN_PAGE_SOURCE]) {
    [FBConfiguration setIncludePlaceholderValueInPageSource:[[settings objectForKey:FB_SETTING_INCLUDE_PLACEHOLDER_VALUE_IN_PAGE_SOURCE] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_INCLUDE_MIN_MAX_VALUE_IN_PAGE_SOURCE]) {
    [FBConfiguration setIncludeMinMaxValueInPageSource:[[settings objectForKey:FB_SETTING_INCLUDE_MIN_MAX_VALUE_IN_PAGE_SOURCE] boolValue]];
  }
  if (nil != [settings objectForKey:FB_SETTING_LIMIT_XPATH_CONTEXT_SCOPE]) {
    [FBConfiguration setLimitXpathContextScope:[[settings objectForKey:FB_SETTING_LIMIT_XPATH_CONTEXT_SCOPE] boolValue]];
  }

#if !TARGET_OS_TV
  if (nil != [settings objectForKey:FB_SETTING_SCREENSHOT_ORIENTATION]) {
    NSError *error;
    if (![FBConfiguration setScreenshotOrientation:(NSString *)[settings objectForKey:FB_SETTING_SCREENSHOT_ORIENTATION]
                                             error:&error]) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                         traceback:nil]);
    }
  }
#endif

  return [self handleGetSettings:request];
}


#pragma mark - Helpers

+ (FBCommandStatus *)configureAutoClickAlertWithSelector:(NSString *)selector
                                              forSession:(FBSession *)session
{
  if (0 == [selector length]) {
    [FBConfiguration setAutoClickAlertSelector:selector];
    [session disableAlertsMonitor];
    return [FBCommandStatus ok];
  }

  NSError *error;
  FBClassChain *parsedChain = [FBClassChainQueryParser parseQuery:selector error:&error];
  if (nil == parsedChain) {
    return [FBCommandStatus invalidSelectorErrorWithMessage:error.localizedDescription
                                                  traceback:nil];
  }
  [FBConfiguration setAutoClickAlertSelector:selector];
  [session enableAlertsMonitor];
  return [FBCommandStatus ok];
}

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
