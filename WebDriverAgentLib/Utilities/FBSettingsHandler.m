/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSettingsHandler.h"

#import "FBActiveAppDetectionPoint.h"
#import "FBClassChainQueryParser.h"
#import "FBCommandStatus.h"
#import "FBConfiguration.h"
#import "FBSession.h"
#import "FBSettings.h"

typedef FBCommandStatus * _Nullable (^FBSettingApplyBlock)(FBSession *session, id value);
typedef id _Nonnull (^FBSettingGetBlock)(FBSession *session);

static id FBNormalizedSettingValue(id value)
{
  return value == NSNull.null ? nil : value;
}

static NSSet<NSString *> *FBNilClearableSettingKeys(void)
{
  static NSSet<NSString *> *keys;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    keys = [NSSet setWithObjects:
      FB_SETTING_DEFAULT_ALERT_ACTION,
      FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR,
      FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR,
      FB_SETTING_AUTO_CLICK_ALERT_SELECTOR,
      nil];
  });
  return keys;
}

@implementation FBSettingsHandler

+ (NSDictionary<NSString *, FBSettingApplyBlock> *)settersMap
{
  static NSDictionary<NSString *, FBSettingApplyBlock> *settersMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary<NSString *, FBSettingApplyBlock> *map = [NSMutableDictionary dictionary];
    map[FB_SETTING_USE_COMPACT_RESPONSES] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setShouldUseCompactResponses:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setElementResponseAttributes:(NSString *)value];
      return nil;
    };
    map[FB_SETTING_MJPEG_SERVER_SCREENSHOT_QUALITY] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setMjpegServerScreenshotQuality:[value unsignedIntegerValue]];
      return nil;
    };
    map[FB_SETTING_MJPEG_SERVER_FRAMERATE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setMjpegServerFramerate:[value unsignedIntegerValue]];
      return nil;
    };
    map[FB_SETTING_SCREENSHOT_QUALITY] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setScreenshotQuality:[value unsignedIntegerValue]];
      return nil;
    };
    map[FB_SETTING_MJPEG_SCALING_FACTOR] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setMjpegScalingFactor:[value floatValue]];
      return nil;
    };
    map[FB_SETTING_MJPEG_FIX_ORIENTATION] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setMjpegShouldFixOrientation:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_KEYBOARD_AUTOCORRECTION] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setKeyboardAutocorrection:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_KEYBOARD_PREDICTION] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setKeyboardPrediction:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_RESPECT_SYSTEM_ALERTS] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setShouldRespectSystemAlerts:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_SNAPSHOT_MAX_DEPTH] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setSnapshotMaxDepth:[value intValue]];
      return nil;
    };
    map[FB_SETTING_SNAPSHOT_MAX_CHILDREN] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setSnapshotMaxChildren:[value intValue]];
      return nil;
    };
    map[FB_SETTING_USE_FIRST_MATCH] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setUseFirstMatch:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_BOUND_ELEMENTS_BY_INDEX] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setBoundElementsByIndex:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_REDUCE_MOTION] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setReduceMotionEnabled:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_DEFAULT_ACTIVE_APPLICATION] = ^FBCommandStatus *(FBSession *session, id value) {
      session.defaultActiveApplication = (NSString *)value;
      return nil;
    };
    map[FB_SETTING_ACTIVE_APP_DETECTION_POINT] = ^FBCommandStatus *(FBSession *session, id value) {
      NSError *error;
      if (![FBActiveAppDetectionPoint.sharedInstance setCoordinatesWithString:(NSString *)value
                                                                        error:&error]) {
        return [FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                      traceback:nil];
      }
      return nil;
    };
    map[FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setAcceptAlertButtonSelector:(NSString *)value];
      return nil;
    };
    map[FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setDismissAlertButtonSelector:(NSString *)value];
      return nil;
    };
    map[FB_SETTING_AUTO_CLICK_ALERT_SELECTOR] = ^FBCommandStatus *(FBSession *session, id value) {
      return [self configureAutoClickAlertWithSelector:(NSString *)value forSession:session];
    };
    map[FB_SETTING_WAIT_FOR_IDLE_TIMEOUT] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setWaitForIdleTimeout:[value doubleValue]];
      return nil;
    };
    map[FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setAnimationCoolOffTimeout:[value doubleValue]];
      return nil;
    };
    map[FB_SETTING_DEFAULT_ALERT_ACTION] = ^FBCommandStatus *(FBSession *session, id value) {
      if (nil == value) {
        session.defaultAlertAction = nil;
      } else if ([value isKindOfClass:NSString.class]) {
        session.defaultAlertAction = [(NSString *)value lowercaseString];
      }
      return nil;
    };
    map[FB_SETTING_MAX_TYPING_FREQUENCY] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setMaxTypingFrequency:[value unsignedIntegerValue]];
      return nil;
    };
    map[FB_SETTING_USE_CLEAR_TEXT_SHORTCUT] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setUseClearTextShortcut:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_INCLUDE_HITTABLE_IN_PAGE_SOURCE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setIncludeHittableInPageSource:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_INCLUDE_NATIVE_FRAME_IN_PAGE_SOURCE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setIncludeNativeFrameInPageSource:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_INCLUDE_NATIVE_ACCESSIBILITY_ELEMENT_IN_PAGE_SOURCE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setIncludeNativeAccessibilityElementInPageSource:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_INCLUDE_MIN_MAX_VALUE_IN_PAGE_SOURCE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setIncludeMinMaxValueInPageSource:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_INCLUDE_CUSTOM_ACTIONS_IN_PAGE_SOURCE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setIncludeCustomActionsInPageSource:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_ENFORCE_CUSTOM_SNAPSHOTS] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setEnforceCustomSnapshots:[value boolValue]];
      return nil;
    };
    map[FB_SETTING_LIMIT_XPATH_CONTEXT_SCOPE] = ^FBCommandStatus *(FBSession *session, id value) {
      [FBConfiguration setLimitXpathContextScope:[value boolValue]];
      return nil;
    };
#if !TARGET_OS_TV
    map[FB_SETTING_SCREENSHOT_ORIENTATION] = ^FBCommandStatus *(FBSession *session, id value) {
      NSError *error;
      if (![FBConfiguration setScreenshotOrientation:(NSString *)value error:&error]) {
        return [FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                      traceback:nil];
      }
      return nil;
    };
#endif
    settersMap = map.copy;
  });
  return settersMap;
}

+ (NSDictionary<NSString *, FBSettingGetBlock> *)gettersMap
{
  static NSDictionary<NSString *, FBSettingGetBlock> *gettersMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary<NSString *, FBSettingGetBlock> *map = [NSMutableDictionary dictionary];
    map[FB_SETTING_USE_COMPACT_RESPONSES] = ^id(FBSession *session) {
      return @([FBConfiguration shouldUseCompactResponses]);
    };
    map[FB_SETTING_ELEMENT_RESPONSE_ATTRIBUTES] = ^id(FBSession *session) {
      return [FBConfiguration elementResponseAttributes];
    };
    map[FB_SETTING_MJPEG_SERVER_SCREENSHOT_QUALITY] = ^id(FBSession *session) {
      return @([FBConfiguration mjpegServerScreenshotQuality]);
    };
    map[FB_SETTING_MJPEG_SERVER_FRAMERATE] = ^id(FBSession *session) {
      return @([FBConfiguration mjpegServerFramerate]);
    };
    map[FB_SETTING_MJPEG_SCALING_FACTOR] = ^id(FBSession *session) {
      return @([FBConfiguration mjpegScalingFactor]);
    };
    map[FB_SETTING_MJPEG_FIX_ORIENTATION] = ^id(FBSession *session) {
      return @([FBConfiguration mjpegShouldFixOrientation]);
    };
    map[FB_SETTING_SCREENSHOT_QUALITY] = ^id(FBSession *session) {
      return @([FBConfiguration screenshotQuality]);
    };
    map[FB_SETTING_KEYBOARD_AUTOCORRECTION] = ^id(FBSession *session) {
      return @([FBConfiguration keyboardAutocorrection]);
    };
    map[FB_SETTING_KEYBOARD_PREDICTION] = ^id(FBSession *session) {
      return @([FBConfiguration keyboardPrediction]);
    };
    map[FB_SETTING_SNAPSHOT_MAX_DEPTH] = ^id(FBSession *session) {
      return @([FBConfiguration snapshotMaxDepth]);
    };
    map[FB_SETTING_SNAPSHOT_MAX_CHILDREN] = ^id(FBSession *session) {
      return @([FBConfiguration snapshotMaxChildren]);
    };
    map[FB_SETTING_USE_FIRST_MATCH] = ^id(FBSession *session) {
      return @([FBConfiguration useFirstMatch]);
    };
    map[FB_SETTING_WAIT_FOR_IDLE_TIMEOUT] = ^id(FBSession *session) {
      return @([FBConfiguration waitForIdleTimeout]);
    };
    map[FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT] = ^id(FBSession *session) {
      return @([FBConfiguration animationCoolOffTimeout]);
    };
    map[FB_SETTING_BOUND_ELEMENTS_BY_INDEX] = ^id(FBSession *session) {
      return @([FBConfiguration boundElementsByIndex]);
    };
    map[FB_SETTING_REDUCE_MOTION] = ^id(FBSession *session) {
      return @([FBConfiguration reduceMotionEnabled]);
    };
    map[FB_SETTING_DEFAULT_ACTIVE_APPLICATION] = ^id(FBSession *session) {
      return session.defaultActiveApplication;
    };
    map[FB_SETTING_ACTIVE_APP_DETECTION_POINT] = ^id(FBSession *session) {
      return FBActiveAppDetectionPoint.sharedInstance.stringCoordinates;
    };
    map[FB_SETTING_ACCEPT_ALERT_BUTTON_SELECTOR] = ^id(FBSession *session) {
      return FBConfiguration.acceptAlertButtonSelector;
    };
    map[FB_SETTING_DISMISS_ALERT_BUTTON_SELECTOR] = ^id(FBSession *session) {
      return FBConfiguration.dismissAlertButtonSelector;
    };
    map[FB_SETTING_AUTO_CLICK_ALERT_SELECTOR] = ^id(FBSession *session) {
      return FBConfiguration.autoClickAlertSelector;
    };
    map[FB_SETTING_DEFAULT_ALERT_ACTION] = ^id(FBSession *session) {
      return session.defaultAlertAction ?: @"";
    };
    map[FB_SETTING_MAX_TYPING_FREQUENCY] = ^id(FBSession *session) {
      return @([FBConfiguration maxTypingFrequency]);
    };
    map[FB_SETTING_RESPECT_SYSTEM_ALERTS] = ^id(FBSession *session) {
      return @([FBConfiguration shouldRespectSystemAlerts]);
    };
    map[FB_SETTING_USE_CLEAR_TEXT_SHORTCUT] = ^id(FBSession *session) {
      return @([FBConfiguration useClearTextShortcut]);
    };
    map[FB_SETTING_INCLUDE_HITTABLE_IN_PAGE_SOURCE] = ^id(FBSession *session) {
      return @([FBConfiguration includeHittableInPageSource]);
    };
    map[FB_SETTING_INCLUDE_NATIVE_FRAME_IN_PAGE_SOURCE] = ^id(FBSession *session) {
      return @([FBConfiguration includeNativeFrameInPageSource]);
    };
    map[FB_SETTING_INCLUDE_NATIVE_ACCESSIBILITY_ELEMENT_IN_PAGE_SOURCE] = ^id(FBSession *session) {
      return @([FBConfiguration includeNativeAccessibilityElementInPageSource]);
    };
    map[FB_SETTING_INCLUDE_MIN_MAX_VALUE_IN_PAGE_SOURCE] = ^id(FBSession *session) {
      return @([FBConfiguration includeMinMaxValueInPageSource]);
    };
    map[FB_SETTING_INCLUDE_CUSTOM_ACTIONS_IN_PAGE_SOURCE] = ^id(FBSession *session) {
      return @([FBConfiguration includeCustomActionsInPageSource]);
    };
    map[FB_SETTING_ENFORCE_CUSTOM_SNAPSHOTS] = ^id(FBSession *session) {
      return @([FBConfiguration enforceCustomSnapshots]);
    };
    map[FB_SETTING_LIMIT_XPATH_CONTEXT_SCOPE] = ^id(FBSession *session) {
      return @([FBConfiguration limitXpathContextScope]);
    };
#if !TARGET_OS_TV
    map[FB_SETTING_SCREENSHOT_ORIENTATION] = ^id(FBSession *session) {
      return [FBConfiguration humanReadableScreenshotOrientation];
    };
#endif
    gettersMap = map.copy;
  });
  return gettersMap;
}

+ (NSDictionary *)currentSettingsForSession:(FBSession *)session
{
  NSDictionary<NSString *, FBSettingGetBlock> *gettersMap = [self gettersMap];
  NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:gettersMap.count];
  for (NSString *key in gettersMap) {
    settings[key] = gettersMap[key](session);
  }
  return settings.copy;
}

+ (nullable FBCommandStatus *)applySettings:(NSDictionary *)settings toSession:(FBSession *)session
{
  NSDictionary<NSString *, FBSettingApplyBlock> *settersMap = [self settersMap];
  NSSet<NSString *> *nilClearableKeys = FBNilClearableSettingKeys();
  for (NSString *key in settings) {
    FBSettingApplyBlock handler = settersMap[key];
    if (nil == handler) {
      continue;
    }
    id value = FBNormalizedSettingValue(settings[key]);
    if (nil == value && ![nilClearableKeys containsObject:key]) {
      continue;
    }
    FBCommandStatus *status = handler(session, value);
    if (status.hasError) {
      return status;
    }
  }
  return nil;
}

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

@end
