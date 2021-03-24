/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBConfiguration.h"

#include <dlfcn.h>
#import <UIKit/UIKit.h>

#include "TargetConditionals.h"
#import "FBXCodeCompatibility.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot.h"
#import "XCTestConfiguration.h"

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
static BOOL FBShouldTerminateApp = YES;
static NSString *FBElementResponseAttributes = @"type,label";
static NSUInteger FBMaxTypingFrequency = 60;
static NSUInteger FBMjpegServerScreenshotQuality = 25;
static NSUInteger FBMjpegServerFramerate = 10;
static NSUInteger FBScreenshotQuality = 1;
static NSUInteger FBMjpegScalingFactor = 100;
static NSTimeInterval FBCustomSnapshotTimeout = 15.;
static BOOL FBShouldUseFirstMatch = NO;
static BOOL FBShouldBoundElementsByIndex = NO;
// This is diabled by default because enabling it prevents the accessbility snapshot to be taken
// (it always errors with kxIllegalArgument error)
static BOOL FBIncludeNonModalElements = NO;
static NSString *FBAcceptAlertButtonSelector = @"";
static NSString *FBDismissAlertButtonSelector = @"";
NSString *const FBSnapshotMaxDepthKey = @"maxDepth";
static NSMutableDictionary *FBSnapshotRequestParameters;
static NSTimeInterval FBWaitForIdleTimeout = 10.;
static NSTimeInterval FBAnimationCoolOffTimeout = 2.;

#if !TARGET_OS_TV
static UIInterfaceOrientation FBScreenshotOrientation = UIInterfaceOrientationUnknown;
#endif

@implementation FBConfiguration

+ (void)initialize
{
  FBSnapshotRequestParameters = [NSMutableDictionary dictionaryWithDictionary:@{
    @"maxArrayCount": @INT_MAX,
    @"maxChildren": @INT_MAX,
    FBSnapshotMaxDepthKey: @50, // 50 should be enough for the majority of the cases. The performance is acceptable for values up to 100.
    @"traverseFromParentsToChildren": @1
  }];
}

#pragma mark Public

+ (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

+ (void)enableXcTestDebugLogs
{
  ((XCTestConfiguration *)XCTestConfiguration.activeTestConfiguration).emitOSLogs = YES;
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTEmitOSLogs"];
}

+ (void)disableAttributeKeyPathAnalysis
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableAttributeKeyPathAnalysis"];
}

+ (void)disableScreenshots
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DisableScreenshots"];
}

+ (void)enableScreenshots
{
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisableScreenshots"];
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

+ (void)setShouldTerminateApp:(BOOL)value
{
  FBShouldTerminateApp = value;
}

+ (BOOL)shouldTerminateApp
{
  return FBShouldTerminateApp;
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

+ (NSTimeInterval)waitForIdleTimeout
{
  return FBWaitForIdleTimeout;
}

+ (void)setWaitForIdleTimeout:(NSTimeInterval)timeout
{
  FBWaitForIdleTimeout = timeout;
}

+ (NSTimeInterval)animationCoolOffTimeout
{
  return FBAnimationCoolOffTimeout;
}

+ (void)setAnimationCoolOffTimeout:(NSTimeInterval)timeout
{
  FBAnimationCoolOffTimeout = timeout;
}

// Works for Simulator and Real devices
+ (void)configureDefaultKeyboardPreferences
{
#if TARGET_OS_SIMULATOR
  // Force toggle software keyboard on.
  // This can avoid 'Keyboard is not present' error which can happen
  // when send_keys are called by client
  [[UIKeyboardImpl sharedInstance] setAutomaticMinimizationEnabled:NO];
  [[UIKeyboardImpl sharedInstance] setSoftwareKeyboardShownByTouch:YES];
#endif

  void *handle = dlopen(controllerPrefBundlePath, RTLD_LAZY);

  Class controllerClass = NSClassFromString(controllerClassName);

  TIPreferencesController *controller = [controllerClass sharedPreferencesController];
  // Auto-Correction in Keyboards
  // 'setAutocorrectionEnabled' Was in TextInput.framework/TIKeyboardState.h over iOS 10.3
  if ([controller respondsToSelector:@selector(setAutocorrectionEnabled:)]) {
    // Under iOS 10.2
    controller.autocorrectionEnabled = NO;
  } else if ([controller respondsToSelector:@selector(setValue:forPreferenceKey:)]) {
    // Over iOS 10.3
    [controller setValue:@NO forPreferenceKey:FBKeyboardAutocorrectionKey];
  }

  // Predictive in Keyboards
  if ([controller respondsToSelector:@selector(setPredictionEnabled:)]) {
    controller.predictionEnabled = NO;
  } else if ([controller respondsToSelector:@selector(setValue:forPreferenceKey:)]) {
    [controller setValue:@NO forPreferenceKey:FBKeyboardPredictionKey];
  }

  // To dismiss keyboard tutorial on iOS 11+ (iPad)
  if ([controller respondsToSelector:@selector(setValue:forPreferenceKey:)]) {
    if (isSDKVersionGreaterThanOrEqualTo(@"11.0")) {
      [controller setValue:@YES forPreferenceKey:@"DidShowGestureKeyboardIntroduction"];
    }
    if (isSDKVersionGreaterThanOrEqualTo(@"13.0")) {
      [controller setValue:@YES forPreferenceKey:@"DidShowContinuousPathIntroduction"];
    }
    [controller synchronizePreferences];
  }

  dlclose(handle);
}

+ (FBConfigurationKeyboardPreference)keyboardAutocorrection
{
  return [self keyboardsPreference:FBKeyboardAutocorrectionKey];
}

+ (void)setKeyboardAutocorrection:(BOOL)isEnabled
{
  [self configureKeyboardsPreference:isEnabled forPreferenceKey:FBKeyboardAutocorrectionKey];
}

+ (FBConfigurationKeyboardPreference)keyboardPrediction
{
  return [self keyboardsPreference:FBKeyboardPredictionKey];
}

+ (void)setKeyboardPrediction:(BOOL)isEnabled
{
  [self configureKeyboardsPreference:isEnabled forPreferenceKey:FBKeyboardPredictionKey];
}

+ (void)setCustomSnapshotTimeout:(NSTimeInterval)timeout
{
  FBCustomSnapshotTimeout = timeout;
}

+ (NSTimeInterval)customSnapshotTimeout
{
  return FBCustomSnapshotTimeout;
}

+ (void)setSnapshotMaxDepth:(int)maxDepth
{
  FBSnapshotRequestParameters[FBSnapshotMaxDepthKey] = @(maxDepth);
}

+ (int)snapshotMaxDepth
{
  return [FBSnapshotRequestParameters[FBSnapshotMaxDepthKey] intValue];
}

+ (NSDictionary *)snapshotRequestParameters
{
  return FBSnapshotRequestParameters;
}

+ (void)setUseFirstMatch:(BOOL)enabled
{
  FBShouldUseFirstMatch = enabled;
}

+ (BOOL)useFirstMatch
{
  return FBShouldUseFirstMatch;
}

+ (void)setBoundElementsByIndex:(BOOL)enabled
{
  FBShouldBoundElementsByIndex = enabled;
}

+ (BOOL)boundElementsByIndex
{
  return FBShouldBoundElementsByIndex;
}

+ (void)setIncludeNonModalElements:(BOOL)isEnabled
{
  FBIncludeNonModalElements = isEnabled;
}

+ (BOOL)includeNonModalElements
{
  return FBIncludeNonModalElements;
}

+ (void)setAcceptAlertButtonSelector:(NSString *)classChainSelector
{
  FBAcceptAlertButtonSelector = classChainSelector;
}

+ (NSString *)acceptAlertButtonSelector
{
  return FBAcceptAlertButtonSelector;
}

+ (void)setDismissAlertButtonSelector:(NSString *)classChainSelector
{
  FBDismissAlertButtonSelector = classChainSelector;
}

+ (NSString *)dismissAlertButtonSelector
{
  return FBDismissAlertButtonSelector;
}

#if !TARGET_OS_TV
+ (BOOL)setScreenshotOrientation:(NSString *)orientation error:(NSError **)error
{
  // Only UIInterfaceOrientationUnknown is over iOS 8. Others are over iOS 2.
  // https://developer.apple.com/documentation/uikit/uiinterfaceorientation/uiinterfaceorientationunknown
  if ([orientation.lowercaseString isEqualToString:@"portrait"]) {
    FBScreenshotOrientation = UIInterfaceOrientationPortrait;
  } else if ([orientation.lowercaseString isEqualToString:@"portraitupsidedown"]) {
    FBScreenshotOrientation = UIInterfaceOrientationPortraitUpsideDown;
  } else if ([orientation.lowercaseString isEqualToString:@"landscaperight"]) {
    FBScreenshotOrientation = UIInterfaceOrientationLandscapeRight;
  } else if ([orientation.lowercaseString isEqualToString:@"landscapeleft"]) {
    FBScreenshotOrientation = UIInterfaceOrientationLandscapeLeft;
  } else if ([orientation.lowercaseString isEqualToString:@"auto"]) {
    FBScreenshotOrientation = UIInterfaceOrientationUnknown;
  } else {
    return [[FBErrorBuilder.builder withDescriptionFormat:
             @"The orientation value '%@' is not known. Only the following orientation values are supported: " \
             "'auto', 'portrait', 'portraitUpsideDown', 'landscapeRight' and 'landscapeLeft'", orientation]
            buildError:error];
  }
  return YES;
}

+ (NSInteger)screenshotOrientation
{
  return FBScreenshotOrientation;
}

+ (NSString *)humanReadableScreenshotOrientation
{
  switch (FBScreenshotOrientation) {
    case UIInterfaceOrientationPortrait:
      return @"portrait";
    case UIInterfaceOrientationPortraitUpsideDown:
      return @"portraitUpsideDown";
    case UIInterfaceOrientationLandscapeRight:
      return @"landscapeRight";
    case UIInterfaceOrientationLandscapeLeft:
      return @"landscapeLeft";
    case UIInterfaceOrientationUnknown:
      return @"auto";
  }
}
#endif

#pragma mark Private

+ (FBConfigurationKeyboardPreference)keyboardsPreference:(nonnull NSString *)key
{
  Class controllerClass = NSClassFromString(controllerClassName);
  TIPreferencesController *controller = [controllerClass sharedPreferencesController];
  if ([key isEqualToString:FBKeyboardAutocorrectionKey]) {
    if ([controller respondsToSelector:@selector(boolForPreferenceKey:)]) {
      return [controller boolForPreferenceKey:FBKeyboardAutocorrectionKey]
        ? FBConfigurationKeyboardPreferenceEnabled
        : FBConfigurationKeyboardPreferenceDisabled;
    } else {
      [FBLogger log:@"Updating keyboard autocorrection preference is not supported"];
      return FBConfigurationKeyboardPreferenceNotSupported;
    }
  } else if ([key isEqualToString:FBKeyboardPredictionKey]) {
    if ([controller respondsToSelector:@selector(boolForPreferenceKey:)]) {
      return [controller boolForPreferenceKey:FBKeyboardPredictionKey]
        ? FBConfigurationKeyboardPreferenceEnabled
        : FBConfigurationKeyboardPreferenceDisabled;
    } else {
      [FBLogger log:@"Updating keyboard prediction preference is not supported"];
      return FBConfigurationKeyboardPreferenceNotSupported;
    }
  }
  @throw [[FBErrorBuilder.builder withDescriptionFormat:@"No available keyboardsPreferenceKey: '%@'", key] build];
}

+ (void)configureKeyboardsPreference:(BOOL)enable forPreferenceKey:(nonnull NSString *)key
{
  void *handle = dlopen(controllerPrefBundlePath, RTLD_LAZY);
  Class controllerClass = NSClassFromString(controllerClassName);

  TIPreferencesController *controller = [controllerClass sharedPreferencesController];

  if ([key isEqualToString:FBKeyboardAutocorrectionKey]) {
    // Auto-Correction in Keyboards
    if ([controller respondsToSelector:@selector(setAutocorrectionEnabled:)]) {
      controller.autocorrectionEnabled = enable;
    } else {
      [controller setValue:@(enable) forPreferenceKey:FBKeyboardAutocorrectionKey];
    }
  } else if ([key isEqualToString:FBKeyboardPredictionKey]) {
    // Predictive in Keyboards
    if ([controller respondsToSelector:@selector(setPredictionEnabled:)]) {
      controller.predictionEnabled = enable;
    } else {
      [controller setValue:@(enable) forPreferenceKey:FBKeyboardPredictionKey];
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
