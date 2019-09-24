/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBConfiguration.h"

#import <UIKit/UIKit.h>

#include "TargetConditionals.h"
#import "FBXCodeCompatibility.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot.h"
#include <dlfcn.h>

static NSUInteger const DefaultStartingPort = 8100;
static NSUInteger const DefaultMjpegServerPort = 9100;
static NSUInteger const DefaultPortRange = 100;

static char const *const controllerPrefBundlePath = "/System/Library/PrivateFrameworks/TextInput.framework/TextInput";
static NSString *const controllerClassName = @"TIPreferencesController";
static NSString *const FBKeyboardAutocorrectionKey = @"KeyboardAutocorrection";
static NSString *const FBKeyboardPredictionKey = @"KeyboardPrediction";
static NSString *const axSettingsClassName = @"AXSettings";

static BOOL FBShouldUseTestManagerForVisibilityDetection = NO;
static BOOL FBShouldUseSingletonTestManager = YES;
static BOOL FBShouldUseCompactResponses = YES;
static BOOL FBShouldWaitForQuiescence = NO;
static NSString *FBElementResponseAttributes = @"type,label";
static NSUInteger FBMaxTypingFrequency = 60;
static NSUInteger FBMjpegServerScreenshotQuality = 25;
static NSUInteger FBMjpegServerFramerate = 10;
static NSUInteger FBScreenshotQuality = 1;
static NSUInteger FBMjpegScalingFactor = 100;
static NSTimeInterval FBSnapshotTimeout = 15.;
static BOOL FBShouldUseFirstMatch = NO;
// This is diabled by default because enabling it prevents the accessbility snapshot to be taken
// (it always errors with kxIllegalArgument error)
static BOOL FBIncludeNonModalElements = NO;

@implementation FBConfiguration

#pragma mark Public

+ (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

+ (void)disableAttributeKeyPathAnalysis
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableAttributeKeyPathAnalysis"];
}

+ (NSRange)bindingPortRange
{
  // 'WebDriverAgent --port 8080' can be passed via the arguments to the process
  if (self.bindingPortRangeFromArguments.location != NSNotFound) {
    return self.bindingPortRangeFromArguments;
  }

  // Existence of USE_PORT in the environment implies the port range is managed by the launching process.
  if (NSProcessInfo.processInfo.environment[@"USE_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"USE_PORT"] length] > 0) {
    return NSMakeRange([NSProcessInfo.processInfo.environment[@"USE_PORT"] integerValue] , 1);
  }

  return NSMakeRange(DefaultStartingPort, DefaultPortRange);
}

+ (NSInteger)mjpegServerPort
{
  if (self.mjpegServerPortFromArguments != NSNotFound) {
    return self.mjpegServerPortFromArguments;
  }
  
  if (NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] length] > 0) {
    return [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] integerValue];
  }

  return DefaultMjpegServerPort;
}

+ (NSUInteger)mjpegScalingFactor
{
  return FBMjpegScalingFactor;
}

+ (void)setMjpegScalingFactor:(NSUInteger)scalingFactor {
  FBMjpegScalingFactor = scalingFactor;
}

+ (BOOL)verboseLoggingEnabled
{
  return [NSProcessInfo.processInfo.environment[@"VERBOSE_LOGGING"] boolValue];
}

+ (void)setShouldUseTestManagerForVisibilityDetection:(BOOL)value
{
  FBShouldUseTestManagerForVisibilityDetection = value;
}

+ (BOOL)shouldUseTestManagerForVisibilityDetection
{
  return FBShouldUseTestManagerForVisibilityDetection;
}

+ (void)setShouldUseCompactResponses:(BOOL)value
{
  FBShouldUseCompactResponses = value;
}

+ (BOOL)shouldUseCompactResponses
{
  return FBShouldUseCompactResponses;
}

+ (void)setElementResponseAttributes:(NSString *)value
{
  FBElementResponseAttributes = value;
}

+ (NSString *)elementResponseAttributes
{
  return FBElementResponseAttributes;
}

+ (void)setMaxTypingFrequency:(NSUInteger)value
{
  FBMaxTypingFrequency = value;
}

+ (NSUInteger)maxTypingFrequency
{
  return FBMaxTypingFrequency;
}

+ (void)setShouldUseSingletonTestManager:(BOOL)value
{
  FBShouldUseSingletonTestManager = value;
}

+ (BOOL)shouldUseSingletonTestManager
{
  return FBShouldUseSingletonTestManager;
}

+ (BOOL)shouldLoadSnapshotWithAttributes
{
  return [XCElementSnapshot fb_attributesForElementSnapshotKeyPathsSelector] != nil;
}

+ (BOOL)shouldWaitForQuiescence
{
  return FBShouldWaitForQuiescence;
}

+ (void)setShouldWaitForQuiescence:(BOOL)value
{
  FBShouldWaitForQuiescence = value;
}

+ (NSUInteger)mjpegServerFramerate
{
  return FBMjpegServerFramerate;
}

+ (void)setMjpegServerFramerate:(NSUInteger)framerate
{
  FBMjpegServerFramerate = framerate;
}

+ (NSUInteger)mjpegServerScreenshotQuality
{
  return FBMjpegServerScreenshotQuality;
}

+ (void)setMjpegServerScreenshotQuality:(NSUInteger)quality
{
  FBMjpegServerScreenshotQuality = quality;
}

+ (NSUInteger)screenshotQuality
{
  return FBScreenshotQuality;
}

+ (void)setScreenshotQuality:(NSUInteger)quality
{
  FBScreenshotQuality = quality;
}

// Works for Simulator and Real devices
+ (void)configureDefaultKeyboardPreferences
{
#if TARGET_OS_SIMULATOR
  // Force toggle software keyboard on.
  // This can avoid 'Keyboard is not present' error which can happen
  // when send_keys are called by client
  [[UIKeyboardImpl sharedInstance] setAutomaticMinimizationEnabled:NO];
#endif

  void *handle = dlopen(controllerPrefBundlePath, RTLD_LAZY);

  Class controllerClass = NSClassFromString(controllerClassName);

  TIPreferencesController *controller = [controllerClass sharedPreferencesController];
  // Auto-Correction in Keyboards
  if ([controller respondsToSelector:@selector(setAutocorrectionEnabled:)]) {
    controller.autocorrectionEnabled = NO;
  } else {
    [controller setValue:@NO forPreferenceKey:FBKeyboardAutocorrectionKey];
  }

  // Predictive in Keyboards
  if ([controller respondsToSelector:@selector(setPredictionEnabled:)]) {
    controller.predictionEnabled = NO;
  } else {
    [controller setValue:@NO forPreferenceKey:FBKeyboardPredictionKey];
  }

  // To dismiss keyboard tutorial on iOS 11+ (iPad)
  if (isSDKVersionGreaterThanOrEqualTo(@"11.0")) {
    [controller setValue:@YES forPreferenceKey:@"DidShowGestureKeyboardIntroduction"];
  }
  if (isSDKVersionGreaterThanOrEqualTo(@"13.0")) {
    [controller setValue:@YES forPreferenceKey:@"DidShowContinuousPathIntroduction"];
  }
  [controller synchronizePreferences];

  dlclose(handle);
}

+ (BOOL)keyboardAutocorrection
{
  return [self keyboardsPreference:FBKeyboardAutocorrectionKey];
}

+ (void)setKeyboardAutocorrection:(BOOL)isEnabled
{
  [self configureKeyboardsPreference:@(isEnabled) forPreferenceKey:FBKeyboardAutocorrectionKey];
}

+ (BOOL)keyboardPrediction
{
  return [self keyboardsPreference:FBKeyboardPredictionKey];
}

+ (void)setKeyboardPrediction:(BOOL)isEnabled
{
  [self configureKeyboardsPreference:@(isEnabled) forPreferenceKey:FBKeyboardPredictionKey];
}

+ (void)setSnapshotTimeout:(NSTimeInterval)timeout
{
  FBSnapshotTimeout = timeout;
}

+ (NSTimeInterval)snapshotTimeout
{
  return FBSnapshotTimeout;
}

+ (void)setUseFirstMatch:(BOOL)enabled
{
  FBShouldUseFirstMatch = enabled;
}

+ (BOOL)useFirstMatch
{
  return FBShouldUseFirstMatch;
}

+ (void)setIncludeNonModalElements:(BOOL)isEnabled
{
  FBIncludeNonModalElements = isEnabled;
}

+ (BOOL)includeNonModalElements
{
  return FBIncludeNonModalElements;
}

#pragma mark Private

+ (BOOL)keyboardsPreference:(nonnull NSString *)key
{
  Class controllerClass = NSClassFromString(controllerClassName);
  TIPreferencesController *controller = [controllerClass sharedPreferencesController];
  if ([key isEqualToString:FBKeyboardAutocorrectionKey]) {
    return [controller boolForPreferenceKey:FBKeyboardAutocorrectionKey];
  } else if ([key isEqualToString:FBKeyboardPredictionKey]) {
    return [controller boolForPreferenceKey:FBKeyboardPredictionKey];
  }
  @throw [[FBErrorBuilder.builder withDescriptionFormat:@"No available keyboardsPreferenceKey: '%@'", key] build];
}

+ (void)configureKeyboardsPreference:(nonnull NSValue *)value forPreferenceKey:(nonnull NSString *)key
{
  void *handle = dlopen(controllerPrefBundlePath, RTLD_LAZY);
  Class controllerClass = NSClassFromString(controllerClassName);

  TIPreferencesController *controller = [controllerClass sharedPreferencesController];

  if ([key isEqualToString:FBKeyboardAutocorrectionKey]) {
    // Auto-Correction in Keyboards
    if ([controller respondsToSelector:@selector(setAutocorrectionEnabled:)]) {
      controller.autocorrectionEnabled = value;
    } else {
      [controller setValue:value forPreferenceKey:FBKeyboardAutocorrectionKey];
    }
  } else if ([key isEqualToString:FBKeyboardPredictionKey]) {
    // Predictive in Keyboards
    if ([controller respondsToSelector:@selector(setPredictionEnabled:)]) {
      controller.predictionEnabled = value;
    } else {
      [controller setValue:value forPreferenceKey:FBKeyboardPredictionKey];
    }
  }

  [controller synchronizePreferences];
  dlclose(handle);
}

+ (NSString*)valueFromArguments: (NSArray<NSString *> *)arguments forKey: (NSString*)key
{
  NSUInteger index = [arguments indexOfObject:key];
  if (index == NSNotFound || index == arguments.count - 1) {
    return nil;
  }
  return arguments[index + 1];
}

+ (NSUInteger)mjpegServerPortFromArguments
{
  NSString *portNumberString = [self valueFromArguments: NSProcessInfo.processInfo.arguments
                                                 forKey: @"--mjpeg-server-port"];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSNotFound;
  }
  return port;
}

+ (NSRange)bindingPortRangeFromArguments
{
  NSString *portNumberString = [self valueFromArguments:NSProcessInfo.processInfo.arguments
                                                 forKey: @"--port"];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(port, 1);
}

+ (void)setReduceMotionEnabled:(BOOL)isEnabled
{
  Class settingsClass = NSClassFromString(axSettingsClassName);
  AXSettings *settings = [settingsClass sharedInstance];

  // Below does not work on real devices because of iOS security model
  //  (lldb) po settings.reduceMotionEnabled = isEnabled
  //  2019-08-21 22:58:19.776165+0900 WebDriverAgentRunner-Runner[322:13361] [User Defaults] Couldn't write value for key ReduceMotionEnabled in CFPrefsPlistSource<0x28111a700> (Domain: com.apple.Accessibility, User: kCFPreferencesCurrentUser, ByHost: No, Container: (null), Contents Need Refresh: No): setting preferences outside an application's container requires user-preference-write or file-write-data sandbox access
  if ([settings respondsToSelector:@selector(setReduceMotionEnabled:)]) {
    [settings setReduceMotionEnabled:isEnabled];
  }
}

+ (BOOL)reduceMotionEnabled
{
  Class settingsClass = NSClassFromString(axSettingsClassName);
  AXSettings *settings = [settingsClass sharedInstance];

  if ([settings respondsToSelector:@selector(reduceMotionEnabled)]) {
    return settings.reduceMotionEnabled;
  }
  return NO;
}
@end
