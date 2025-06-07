/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBConfiguration.h"

#import "AXSettings.h"
#import "UIKeyboardImpl.h"
#import "TIPreferencesController.h"

#include <dlfcn.h>
#import <UIKit/UIKit.h>

#include "TargetConditionals.h"
#import "FBXCodeCompatibility.h"
#import "XCAXClient_iOS+FBSnapshotReqParams.h"
#import "XCTestPrivateSymbols.h"
#import "XCTestConfiguration.h"
#import "XCUIApplication+FBUIInterruptions.h"

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
static BOOL FBShouldRespectSystemAlerts = NO;

static CGFloat FBMjpegScalingFactor = 100.0;
static BOOL FBMjpegShouldFixOrientation = NO;
static NSUInteger FBMjpegServerScreenshotQuality = 25;
static NSUInteger FBMjpegServerFramerate = 10;

// Session-specific settings
static BOOL FBShouldTerminateApp;
static NSNumber* FBMaxTypingFrequency;
static NSUInteger FBScreenshotQuality;
static BOOL FBShouldUseFirstMatch;
static BOOL FBShouldBoundElementsByIndex;
static BOOL FBIncludeNonModalElements;
static NSString *FBAcceptAlertButtonSelector;
static NSString *FBDismissAlertButtonSelector;
static NSString *FBAutoClickAlertSelector;
static NSTimeInterval FBWaitForIdleTimeout;
static NSTimeInterval FBAnimationCoolOffTimeout;
static BOOL FBShouldUseCompactResponses;
static NSString *FBElementResponseAttributes;
static BOOL FBUseClearTextShortcut;
static BOOL FBLimitXpathContextScope = YES;
#if !TARGET_OS_TV
static UIInterfaceOrientation FBScreenshotOrientation;
#endif
static BOOL FBShouldIncludeHittableInPageSource = NO;
static BOOL FBShouldIncludeNativeFrameInPageSource = NO;
static BOOL FBShouldIncludePlaceholderValueInPageSource = NO;
static BOOL FBShouldIncludeMinMaxValueInPageSource = NO;

@implementation FBConfiguration

+ (NSUInteger)defaultTypingFrequency
{
  NSInteger defaultFreq = [[NSUserDefaults standardUserDefaults]
                           integerForKey:@"com.apple.xctest.iOSMaximumTypingFrequency"];
  return defaultFreq > 0 ? defaultFreq : 60;
}

+ (void)initialize
{
  [FBConfiguration resetSessionSettings];
}

#pragma mark Public

+ (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

+ (void)disableApplicationUIInterruptionsHandling
{
  [XCUIApplication fb_disableUIInterruptionsHandling];
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

+ (void)disableScreenRecordings
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DisableDiagnosticScreenRecordings"];
}

+ (void)enableScreenRecordings
{
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisableDiagnosticScreenRecordings"];
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

+ (CGFloat)mjpegScalingFactor
{
  return FBMjpegScalingFactor;
}

+ (void)setMjpegScalingFactor:(CGFloat)scalingFactor {
  FBMjpegScalingFactor = scalingFactor;
}

+ (BOOL)mjpegShouldFixOrientation
{
  return FBMjpegShouldFixOrientation;
}

+ (void)setMjpegShouldFixOrientation:(BOOL)enabled {
  FBMjpegShouldFixOrientation = enabled;
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
  FBMaxTypingFrequency = @(value);
}

+ (NSUInteger)maxTypingFrequency
{
  if (nil == FBMaxTypingFrequency) {
    return [self defaultTypingFrequency];
  }
  return FBMaxTypingFrequency.integerValue <= 0 
    ? [self defaultTypingFrequency]
    : FBMaxTypingFrequency.integerValue;
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
    [controller setValue:@YES forPreferenceKey:@"DidShowGestureKeyboardIntroduction"];
    if (isSDKVersionGreaterThanOrEqualTo(@"13.0")) {
      [controller setValue:@YES forPreferenceKey:@"DidShowContinuousPathIntroduction"];
    }
    [controller synchronizePreferences];
  }

  dlclose(handle);
}

+ (void)forceSimulatorSoftwareKeyboardPresence
{
#if TARGET_OS_SIMULATOR
  // Force toggle software keyboard on.
  // This can avoid 'Keyboard is not present' error which can happen
  // when send_keys are called by client
  [[UIKeyboardImpl sharedInstance] setAutomaticMinimizationEnabled:NO];

  if ([(NSObject *)[UIKeyboardImpl sharedInstance]
       respondsToSelector:@selector(setSoftwareKeyboardShownByTouch:)]) {
    // Xcode 13 no longer has this method
    [[UIKeyboardImpl sharedInstance] setSoftwareKeyboardShownByTouch:YES];
  }
#endif
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

+ (void)setSnapshotMaxDepth:(int)maxDepth
{
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey, @(maxDepth));
}

+ (int)snapshotMaxDepth
{
  return [FBGetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey) intValue];
}

+ (void)setShouldRespectSystemAlerts:(BOOL)value
{
  FBShouldRespectSystemAlerts = value;
}

+ (BOOL)shouldRespectSystemAlerts
{
  return FBShouldRespectSystemAlerts;
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

+ (void)setAutoClickAlertSelector:(NSString *)classChainSelector
{
  FBAutoClickAlertSelector = classChainSelector;
}

+ (NSString *)autoClickAlertSelector
{
  return FBAutoClickAlertSelector;
}

+ (void)setUseClearTextShortcut:(BOOL)enabled
{
  FBUseClearTextShortcut = enabled;
}

+ (BOOL)useClearTextShortcut
{
  return FBUseClearTextShortcut;
}

+ (BOOL)limitXpathContextScope
{
  return FBLimitXpathContextScope;
}

+ (void)setLimitXpathContextScope:(BOOL)enabled
{
  FBLimitXpathContextScope = enabled;
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

+ (void)resetSessionSettings
{
  FBShouldTerminateApp = YES;
  FBShouldUseCompactResponses = YES;
  FBElementResponseAttributes = @"type,label";
  FBMaxTypingFrequency = @([self defaultTypingFrequency]);
  FBScreenshotQuality = 3;
  FBShouldUseFirstMatch = NO;
  FBShouldBoundElementsByIndex = NO;
  // This is diabled by default because enabling it prevents the accessbility snapshot to be taken
  // (it always errors with kxIllegalArgument error)
  FBIncludeNonModalElements = NO;
  FBAcceptAlertButtonSelector = @"";
  FBDismissAlertButtonSelector = @"";
  FBAutoClickAlertSelector = @"";
  FBWaitForIdleTimeout = 10.;
  FBAnimationCoolOffTimeout = 2.;
  // 50 should be enough for the majority of the cases. The performance is acceptable for values up to 100.
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey, @50);
  FBUseClearTextShortcut = YES;
  FBLimitXpathContextScope = YES;
#if !TARGET_OS_TV
  FBScreenshotOrientation = UIInterfaceOrientationUnknown;
#endif
}

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

+ (void)setIncludeHittableInPageSource:(BOOL)enabled
{
  FBShouldIncludeHittableInPageSource = enabled;
}

+ (BOOL)includeHittableInPageSource
{
  return FBShouldIncludeHittableInPageSource;
}

+ (void)setIncludeNativeFrameInPageSource:(BOOL)enabled
{
  FBShouldIncludeNativeFrameInPageSource = enabled;
}

+ (BOOL)includeNativeFrameInPageSource
{
  return FBShouldIncludeNativeFrameInPageSource;
}

+ (void)setIncludePlaceholderValueInPageSource:(BOOL)enabled
{
  FBShouldIncludePlaceholderValueInPageSource = enabled;
}

+ (BOOL)includePlaceholderValueInPageSource
{
  return FBShouldIncludePlaceholderValueInPageSource;
}

+ (void)setIncludeMinMaxValueInPageSource:(BOOL)enabled
{
  FBShouldIncludeMinMaxValueInPageSource = enabled;
}

+ (BOOL)includeMinMaxValueInPageSource
{
  return FBShouldIncludeMinMaxValueInPageSource;
}

@end
