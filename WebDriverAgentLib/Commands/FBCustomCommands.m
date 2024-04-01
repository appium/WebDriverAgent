/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCustomCommands.h"

#import <XCTest/XCUIDevice.h>
#import <CoreLocation/CoreLocation.h>

#import "FBConfiguration.h"
#import "FBKeyboard.h"
#import "FBNotificationsHelper.h"
#import "FBMathUtils.h"
#import "FBPasteboard.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElementQuery.h"
#import "FBUnattachedAppLauncher.h"

@implementation FBCustomCommands

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/timeouts"] respondWithTarget:self action:@selector(handleTimeouts:)],
    [[FBRoute POST:@"/wda/homescreen"].withoutSession respondWithTarget:self action:@selector(handleHomescreenCommand:)],
    [[FBRoute POST:@"/wda/deactivateApp"] respondWithTarget:self action:@selector(handleDeactivateAppCommand:)],
    [[FBRoute POST:@"/wda/keyboard/dismiss"] respondWithTarget:self action:@selector(handleDismissKeyboardCommand:)],
    [[FBRoute POST:@"/wda/lock"].withoutSession respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/lock"] respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/unlock"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute POST:@"/wda/unlock"] respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute GET:@"/wda/locked"].withoutSession respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/locked"] respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/screen"] respondWithTarget:self action:@selector(handleGetScreen:)],
    [[FBRoute GET:@"/wda/screen"].withoutSession respondWithTarget:self action:@selector(handleGetScreen:)],
    [[FBRoute GET:@"/wda/activeAppInfo"] respondWithTarget:self action:@selector(handleActiveAppInfo:)],
    [[FBRoute GET:@"/wda/activeAppInfo"].withoutSession respondWithTarget:self action:@selector(handleActiveAppInfo:)],
#if !TARGET_OS_TV // tvOS does not provide relevant APIs
    [[FBRoute POST:@"/wda/setPasteboard"] respondWithTarget:self action:@selector(handleSetPasteboard:)],
    [[FBRoute POST:@"/wda/setPasteboard"].withoutSession respondWithTarget:self action:@selector(handleSetPasteboard:)],
    [[FBRoute POST:@"/wda/getPasteboard"] respondWithTarget:self action:@selector(handleGetPasteboard:)],
    [[FBRoute POST:@"/wda/getPasteboard"].withoutSession respondWithTarget:self action:@selector(handleGetPasteboard:)],
    [[FBRoute GET:@"/wda/batteryInfo"] respondWithTarget:self action:@selector(handleGetBatteryInfo:)],
#endif
    [[FBRoute POST:@"/wda/pressButton"] respondWithTarget:self action:@selector(handlePressButtonCommand:)],
    [[FBRoute POST:@"/wda/performAccessibilityAudit"] respondWithTarget:self action:@selector(handlePerformAccessibilityAudit:)],
    [[FBRoute POST:@"/wda/performIoHidEvent"] respondWithTarget:self action:@selector(handlePeformIOHIDEvent:)],
    [[FBRoute POST:@"/wda/expectNotification"] respondWithTarget:self action:@selector(handleExpectNotification:)],
    [[FBRoute POST:@"/wda/siri/activate"] respondWithTarget:self action:@selector(handleActivateSiri:)],
    [[FBRoute POST:@"/wda/apps/launchUnattached"].withoutSession respondWithTarget:self action:@selector(handleLaunchUnattachedApp:)],
    [[FBRoute GET:@"/wda/device/info"] respondWithTarget:self action:@selector(handleGetDeviceInfo:)],
    [[FBRoute POST:@"/wda/resetAppAuth"] respondWithTarget:self action:@selector(handleResetAppAuth:)],
    [[FBRoute GET:@"/wda/device/info"].withoutSession respondWithTarget:self action:@selector(handleGetDeviceInfo:)],
    [[FBRoute POST:@"/wda/device/appearance"].withoutSession respondWithTarget:self action:@selector(handleSetDeviceAppearance:)],
    [[FBRoute GET:@"/wda/device/location"] respondWithTarget:self action:@selector(handleGetLocation:)],
    [[FBRoute GET:@"/wda/device/location"].withoutSession respondWithTarget:self action:@selector(handleGetLocation:)],
#if !TARGET_OS_TV // tvOS does not provide relevant APIs
#if __clang_major__ >= 15
    [[FBRoute POST:@"/wda/element/:uuid/keyboardInput"] respondWithTarget:self action:@selector(handleKeyboardInput:)],
#endif
    [[FBRoute GET:@"/wda/simulatedLocation"] respondWithTarget:self action:@selector(handleGetSimulatedLocation:)],
    [[FBRoute GET:@"/wda/simulatedLocation"].withoutSession respondWithTarget:self action:@selector(handleGetSimulatedLocation:)],
    [[FBRoute POST:@"/wda/simulatedLocation"] respondWithTarget:self action:@selector(handleSetSimulatedLocation:)],
    [[FBRoute POST:@"/wda/simulatedLocation"].withoutSession respondWithTarget:self action:@selector(handleSetSimulatedLocation:)],
    [[FBRoute DELETE:@"/wda/simulatedLocation"] respondWithTarget:self action:@selector(handleClearSimulatedLocation:)],
    [[FBRoute DELETE:@"/wda/simulatedLocation"].withoutSession respondWithTarget:self action:@selector(handleClearSimulatedLocation:)],
#endif
    [[FBRoute OPTIONS:@"/*"].withoutSession respondWithTarget:self action:@selector(handlePingCommand:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_goToHomescreenWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDeactivateAppCommand:(FBRouteRequest *)request
{
  NSNumber *requestedDuration = request.arguments[@"duration"];
  NSTimeInterval duration = (requestedDuration ? requestedDuration.doubleValue : 3.);
  NSError *error;
  if (![request.session.activeApplication fb_deactivateWithDuration:duration error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTimeouts:(FBRouteRequest *)request
{
  // This method is intentionally not supported.
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDismissKeyboardCommand:(FBRouteRequest *)request
{
  NSError *error;
  BOOL isDismissed = [request.session.activeApplication fb_dismissKeyboardWithKeyNames:request.arguments[@"keyNames"]
                                                                                 error:&error];
  return isDismissed
  ? FBResponseWithOK()
  : FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description
                                                                    traceback:nil]);
}

+ (id<FBResponsePayload>)handlePingCommand:(FBRouteRequest *)request
{
  return FBResponseWithOK();
}

#pragma mark - Helpers

+ (id<FBResponsePayload>)handleGetScreen:(FBRouteRequest *)request
{
  XCUIApplication *app = XCUIApplication.fb_systemApplication;

  XCUIElement *mainStatusBar = app.statusBars.allElementsBoundByIndex.firstObject;
  CGSize statusBarSize = (nil == mainStatusBar) ? CGSizeZero : mainStatusBar.frame.size;

#if TARGET_OS_TV
  CGSize screenSize = app.frame.size;
#else
  CGSize screenSize = FBAdjustDimensionsForApplication(app.wdFrame.size, app.interfaceOrientation);
#endif

  return FBResponseWithObject(
                              @{
    @"screenSize":@{@"width": @(screenSize.width),
                    @"height": @(screenSize.height)
    },
    @"statusBarSize": @{@"width": @(statusBarSize.width),
                        @"height": @(statusBarSize.height),
    },
    @"scale": @([FBScreen scale]),
  });
}

+ (id<FBResponsePayload>)handleLock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_lockScreen:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleIsLocked:(FBRouteRequest *)request
{
  BOOL isLocked = [XCUIDevice sharedDevice].fb_isScreenLocked;
  return FBResponseWithObject(isLocked ? @YES : @NO);
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_unlockScreen:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActiveAppInfo:(FBRouteRequest *)request
{
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  return FBResponseWithObject(@{
    @"pid": @(app.processID),
    @"bundleId": app.bundleID,
    @"name": app.identifier,
    @"processArguments": [self processArguments:app],
  });
}

/**
 * Returns current active app and its arguments of active session
 *
 * @return The dictionary of current active bundleId and its process/environment argumens
 *
 * @example
 *
 *     [self currentActiveApplication]
 *     //=> {
 *     //       "processArguments" : {
 *     //       "env" : {
 *     //           "HAPPY" : "testing"
 *     //       },
 *     //       "args" : [
 *     //           "happy",
 *     //           "tseting"
 *     //       ]
 *     //   }
 *
 *     [self currentActiveApplication]
 *     //=> {}
 */
+ (NSDictionary *)processArguments:(XCUIApplication *)app
{
  // Can be nil if no active activation is defined by XCTest
  if (app == nil) {
    return @{};
  }

  return
  @{
    @"args": app.launchArguments,
    @"env": app.launchEnvironment
  };
}

#if !TARGET_OS_TV
+ (id<FBResponsePayload>)handleSetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSData *content = [[NSData alloc] initWithBase64EncodedString:(NSString *)request.arguments[@"content"]
                                                        options:NSDataBase64DecodingIgnoreUnknownCharacters];
  if (nil == content) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Cannot decode the pasteboard content from base64" traceback:nil]);
  }
  NSError *error;
  if (![FBPasteboard setData:content forType:contentType error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSError *error;
  id result = [FBPasteboard dataForType:contentType error:&error];
  if (nil == result) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithObject([result base64EncodedStringWithOptions:0]);
}

+ (id<FBResponsePayload>)handleGetBatteryInfo:(FBRouteRequest *)request
{
  if (![[UIDevice currentDevice] isBatteryMonitoringEnabled]) {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  }
  return FBResponseWithObject(@{
    @"level": @([UIDevice currentDevice].batteryLevel),
    @"state": @([UIDevice currentDevice].batteryState)
  });
}
#endif

+ (id<FBResponsePayload>)handlePressButtonCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_pressButton:(id)request.arguments[@"name"]
                                   forDuration:(NSNumber *)request.arguments[@"duration"]
                                         error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActivateSiri:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_activateSiriVoiceRecognitionWithText:(id)request.arguments[@"text"] error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id <FBResponsePayload>)handlePeformIOHIDEvent:(FBRouteRequest *)request
{
  NSNumber *page = request.arguments[@"page"];
  NSNumber *usage = request.arguments[@"usage"];
  NSNumber *duration = request.arguments[@"duration"];
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_performIOHIDEventWithPage:page.unsignedIntValue
                                                       usage:usage.unsignedIntValue
                                                    duration:duration.doubleValue
                                                       error:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id <FBResponsePayload>)handleLaunchUnattachedApp:(FBRouteRequest *)request
{
  NSString *bundle = (NSString *)request.arguments[@"bundleId"];
  if ([FBUnattachedAppLauncher launchAppWithBundleId:bundle]) {
    return FBResponseWithOK();
  }
  return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:@"LSApplicationWorkspace failed to launch app" traceback:nil]);
}

+ (id <FBResponsePayload>)handleResetAppAuth:(FBRouteRequest *)request
{
  NSNumber *resource = request.arguments[@"resource"];
  if (nil == resource) {
    NSString *errMsg = @"The 'resource' argument must be set to a valid resource identifier (numeric value). See https://developer.apple.com/documentation/xctest/xcuiprotectedresource?language=objc";
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:errMsg traceback:nil]);
  }
  [request.session.activeApplication resetAuthorizationStatusForResource:(XCUIProtectedResource)resource.longLongValue];
  return FBResponseWithOK();
}

/**
 Returns device location data.
 It requires to configure location access permission by manual.
 The response of 'latitude', 'longitude' and 'altitude' are always zero (0) without authorization.
 'authorizationStatus' indicates current authorization status. '3' is 'Always'.
 https://developer.apple.com/documentation/corelocation/clauthorizationstatus

 Settings -> Privacy -> Location Service -> WebDriverAgent-Runner -> Always

 The return value could be zero even if the permission is set to 'Always'
 since the location service needs some time to update the location data.
 */
+ (id<FBResponsePayload>)handleGetLocation:(FBRouteRequest *)request
{
#if TARGET_OS_TV
  return FBResponseWithStatus([FBCommandStatus unsupportedOperationErrorWithMessage:@"unsupported"
                                                                          traceback:nil]);
#else
  CLLocationManager *locationManager = [[CLLocationManager alloc] init];
  [locationManager setDistanceFilter:kCLHeadingFilterNone];
  // Always return the best acurate location data
  [locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
  [locationManager setPausesLocationUpdatesAutomatically:NO];
  [locationManager startUpdatingLocation];

  CLAuthorizationStatus authStatus;
  if ([locationManager respondsToSelector:@selector(authorizationStatus)]) {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[locationManager class]
                                                                            instanceMethodSignatureForSelector:@selector(authorizationStatus)]];
    [invocation setSelector:@selector(authorizationStatus)];
    [invocation setTarget:locationManager];
    [invocation invoke];
    [invocation getReturnValue:&authStatus];
  } else {
    authStatus = [CLLocationManager authorizationStatus];
  }

  return FBResponseWithObject(@{
    @"authorizationStatus": @(authStatus),
    @"latitude": @(locationManager.location.coordinate.latitude),
    @"longitude": @(locationManager.location.coordinate.longitude),
    @"altitude": @(locationManager.location.altitude),
  });
#endif
}

+ (id<FBResponsePayload>)handleExpectNotification:(FBRouteRequest *)request
{
  NSString *name = request.arguments[@"name"];
  if (nil == name) {
    NSString *message = @"Notification name argument must be provided";
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message traceback:nil]);
  }
  NSNumber *timeout = request.arguments[@"timeout"] ?: @60;
  NSString *type = request.arguments[@"type"] ?: @"plain";

  XCTWaiterResult result;
  if ([type isEqualToString:@"plain"]) {
    result = [FBNotificationsHelper waitForNotificationWithName:name timeout:timeout.doubleValue];
  } else if ([type isEqualToString:@"darwin"]) {
    result = [FBNotificationsHelper waitForDarwinNotificationWithName:name timeout:timeout.doubleValue];
  } else {
    NSString *message = [NSString stringWithFormat:@"Notification type could only be 'plain' or 'darwin'. Got '%@' instead", type];
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message traceback:nil]);
  }
  if (result != XCTWaiterResultCompleted) {
    NSString *message = [NSString stringWithFormat:@"Did not receive any expected %@ notifications within %@s",
                         name, timeout];
    return FBResponseWithStatus([FBCommandStatus timeoutErrorWithMessage:message traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSetDeviceAppearance:(FBRouteRequest *)request
{
  NSString *name = [request.arguments[@"name"] lowercaseString];
  if (nil == name || !([name isEqualToString:@"light"] || [name isEqualToString:@"dark"])) {
    NSString *message = @"The appearance name must be either 'light' or 'dark'";
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message traceback:nil]);
  }

  FBUIInterfaceAppearance appearance = [name isEqualToString:@"light"]
  ? FBUIInterfaceAppearanceLight
  : FBUIInterfaceAppearanceDark;
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_setAppearance:appearance error:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetDeviceInfo:(FBRouteRequest *)request
{
  // Returns locale like ja_EN and zh-Hant_US. The format depends on OS
  // Developers should use this locale by default
  // https://developer.apple.com/documentation/foundation/nslocale/1414388-autoupdatingcurrentlocale
  NSString *currentLocale = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];

  NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionaryWithDictionary:
                                     @{
    @"currentLocale": currentLocale,
    @"timeZone": self.timeZone,
    @"name": UIDevice.currentDevice.name,
    @"model": UIDevice.currentDevice.model,
    @"uuid": [UIDevice.currentDevice.identifierForVendor UUIDString] ?: @"unknown",
    // https://developer.apple.com/documentation/uikit/uiuserinterfaceidiom?language=objc
    @"userInterfaceIdiom": @(UIDevice.currentDevice.userInterfaceIdiom),
    @"userInterfaceStyle": self.userInterfaceStyle,
#if TARGET_OS_SIMULATOR
    @"isSimulator": @(YES),
#else
    @"isSimulator": @(NO),
#endif
  }];

  // https://developer.apple.com/documentation/foundation/nsprocessinfothermalstate
  deviceInfo[@"thermalState"] = @(NSProcessInfo.processInfo.thermalState);

  return FBResponseWithObject(deviceInfo);
}

/**
 * @return Current user interface style as a string
 */
+ (NSString *)userInterfaceStyle
{

  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
    // Only iOS 15+ simulators/devices return correct data while
    // the api itself works in iOS 13 and 14 that has style preference.
    NSNumber *appearance = [XCUIDevice.sharedDevice fb_getAppearance];
    if (appearance != nil) {
      return [self getAppearanceName:appearance];
    }
  }

  static id userInterfaceStyle = nil;
  static dispatch_once_t styleOnceToken;
  dispatch_once(&styleOnceToken, ^{
    if ([UITraitCollection respondsToSelector:NSSelectorFromString(@"currentTraitCollection")]) {
      id currentTraitCollection = [UITraitCollection performSelector:NSSelectorFromString(@"currentTraitCollection")];
      if (nil != currentTraitCollection) {
        userInterfaceStyle = [currentTraitCollection valueForKey:@"userInterfaceStyle"];
      }
    }
  });

  if (nil == userInterfaceStyle) {
    return @"unsupported";
  }

  return [self getAppearanceName:userInterfaceStyle];
}

+ (NSString *)getAppearanceName:(NSNumber *)appearance
{
  switch ([appearance longLongValue]) {
    case FBUIInterfaceAppearanceUnspecified:
      return @"automatic";
    case FBUIInterfaceAppearanceLight:
      return @"light";
    case FBUIInterfaceAppearanceDark:
      return @"dark";
    default:
      return @"unknown";
  }
}

/**
 * @return The string of TimeZone. Returns TZ timezone id by default. Returns TimeZone name by Apple if TZ timezone id is not available.
 */
+ (NSString *)timeZone
{
  NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
  // Apple timezone name like "US/New_York"
  NSString *timeZoneAbb = [localTimeZone abbreviation];
  if (timeZoneAbb == nil) {
    return [localTimeZone name];
  }

  // Convert timezone name to ids like "America/New_York" as TZ database Time Zones format
  // https://developer.apple.com/documentation/foundation/nstimezone
  NSString *timeZoneId = [[NSTimeZone timeZoneWithAbbreviation:timeZoneAbb] name];
  if (timeZoneId != nil) {
    return timeZoneId;
  }

  return [localTimeZone name];
}

#if !TARGET_OS_TV // tvOS does not provide relevant APIs
+ (id<FBResponsePayload>)handleGetSimulatedLocation:(FBRouteRequest *)request
{
  NSError *error;
  CLLocation *location = [XCUIDevice.sharedDevice fb_getSimulatedLocation:&error];
  if (nil != error) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithObject(@{
    @"latitude": location ? @(location.coordinate.latitude) : NSNull.null,
    @"longitude": location ? @(location.coordinate.longitude) : NSNull.null,
    @"altitude": location ? @(location.altitude) : NSNull.null,
  });
}

+ (id<FBResponsePayload>)handleSetSimulatedLocation:(FBRouteRequest *)request
{
  NSNumber *longitude = request.arguments[@"longitude"];
  NSNumber *latitude = request.arguments[@"latitude"];

  if (nil == longitude || nil == latitude) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Both latitude and longitude must be provided"
                                                                       traceback:nil]);
  }
  NSError *error;
  CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude.doubleValue
                                                    longitude:longitude.doubleValue];
  if (![XCUIDevice.sharedDevice fb_setSimulatedLocation:location error:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleClearSimulatedLocation:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_clearSimulatedLocation:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

#if __clang_major__ >= 15
+ (id<FBResponsePayload>)handleKeyboardInput:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  BOOL hasElement = ![request.parameters[@"uuid"] isEqual:@"0"];
  XCUIElement *destination = hasElement
    ? [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]]
    : request.session.activeApplication;
  id keys = request.arguments[@"keys"];

  if (![destination respondsToSelector:@selector(typeKey:modifierFlags:)]) {
    NSString *message = @"typeKey API is only supported since Xcode15 and iPadOS 17";
    return FBResponseWithStatus([FBCommandStatus unsupportedOperationErrorWithMessage:message
                                                                            traceback:nil]);
  }

  if (![keys isKindOfClass:NSArray.class]) {
    NSString *message = @"The 'keys' argument must be an array";
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message
                                                                       traceback:nil]);
  }
  for (id item in (NSArray *)keys) {
    if ([item isKindOfClass:NSString.class]) {
      NSString *keyValue = [FBKeyboard keyValueForName:item] ?: item;
      [destination typeKey:keyValue modifierFlags:XCUIKeyModifierNone];
    } else if ([item isKindOfClass:NSDictionary.class]) {
      id key = [(NSDictionary *)item objectForKey:@"key"];
      if (![key isKindOfClass:NSString.class]) {
        NSString *message = [NSString stringWithFormat:@"All dictionaries of 'keys' array must have the 'key' item of type string. Got '%@' instead in the item %@", key, item];
        return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message
                                                                           traceback:nil]);
      }
      id modifiers = [(NSDictionary *)item objectForKey:@"modifierFlags"];
      NSUInteger modifierFlags = XCUIKeyModifierNone;
      if ([modifiers isKindOfClass:NSNumber.class]) {
        modifierFlags = [(NSNumber *)modifiers unsignedIntValue];
      }
      NSString *keyValue = [FBKeyboard keyValueForName:item] ?: key;
      [destination typeKey:keyValue modifierFlags:modifierFlags];
    } else {
      NSString *message = @"All items of the 'keys' array must be either dictionaries or strings";
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message
                                                                         traceback:nil]);
    }
  }
  return FBResponseWithOK();
}
#endif
#endif

+ (id<FBResponsePayload>)handlePerformAccessibilityAudit:(FBRouteRequest *)request
{
  NSError *error;
  NSArray *requestedTypes = request.arguments[@"auditTypes"];
  NSMutableSet *typesSet = [NSMutableSet set];
  if (nil == requestedTypes || 0 == [requestedTypes count]) {
    [typesSet addObject:@"XCUIAccessibilityAuditTypeAll"];
  } else {
    [typesSet addObjectsFromArray:requestedTypes];
  }
  NSArray *result = [request.session.activeApplication fb_performAccessibilityAuditWithAuditTypesSet:typesSet.copy
                                                                                               error:&error];
  if (nil == result) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithObject(result);
}

@end
