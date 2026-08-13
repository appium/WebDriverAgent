/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBConfiguration.h"

#import "AXSettings.h"
#import "UIKeyboardImpl.h"
#import "TIPreferencesController.h"

#include <dlfcn.h>
#include <limits.h>
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
static UInt64 const DefaultHttpRequestBodySizeLimit = 1024ull * 1024ull * 1024ull;

static char const *const controllerPrefBundlePath = "/System/Library/PrivateFrameworks/TextInput.framework/TextInput";
static NSString *const controllerClassName = @"TIPreferencesController";
static NSString *const FBKeyboardAutocorrectionKey = @"KeyboardAutocorrection";
static NSString *const FBKeyboardPredictionKey = @"KeyboardPrediction";
static NSString *const axSettingsClassName = @"AXSettings";

@interface FBConfiguration ()

@property (atomic, strong) NSNumber *maxTypingFrequencyOverride;
#if !TARGET_OS_TV
@property (atomic, assign) UIInterfaceOrientation screenshotOrientationStorage;
#endif

@end

@implementation FBConfiguration

+ (instancetype)sharedInstance
{
  static FBConfiguration *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [FBConfiguration new];
  });
  return instance;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    // Process-level defaults that are intentionally NOT reset by -resetSessionSettings
    self.shouldUseSingletonTestManager = YES;
    self.mjpegScalingFactor = 100.0;
    self.mjpegServerScreenshotQuality = 25;
    self.mjpegServerFramerate = 10;

    [self resetSessionSettings];
  }
  return self;
}

- (NSUInteger)defaultTypingFrequency
{
  NSInteger defaultFreq = [[NSUserDefaults standardUserDefaults]
                           integerForKey:@"com.apple.xctest.iOSMaximumTypingFrequency"];
  return defaultFreq > 0 ? defaultFreq : 60;
}

#pragma mark Public

- (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

- (void)disableApplicationUIInterruptionsHandling
{
  [XCUIApplication fb_disableUIInterruptionsHandling];
}

- (void)enableXcTestDebugLogs
{
  ((XCTestConfiguration *)XCTestConfiguration.activeTestConfiguration).emitOSLogs = YES;
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTEmitOSLogs"];
}

- (void)disableAttributeKeyPathAnalysis
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableAttributeKeyPathAnalysis"];
}

- (void)disableScreenshots
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DisableScreenshots"];
}

- (void)enableScreenshots
{
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisableScreenshots"];
}

- (void)disableScreenRecordings
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DisableDiagnosticScreenRecordings"];
}

- (void)enableScreenRecordings
{
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisableDiagnosticScreenRecordings"];
}

- (NSRange)bindingPortRange
{
  // 'WebDriverAgent --port 8080' can be passed via the arguments to the process
  NSRange rangeFromArguments = [self.class bindingPortRangeFromArguments];
  if (rangeFromArguments.location != NSNotFound) {
    return rangeFromArguments;
  }

  // Existence of USE_PORT in the environment implies the port range is managed by the launching process.
  if (NSProcessInfo.processInfo.environment[@"USE_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"USE_PORT"] length] > 0) {
    return NSMakeRange([NSProcessInfo.processInfo.environment[@"USE_PORT"] integerValue] , 1);
  }

  return NSMakeRange(DefaultStartingPort, DefaultPortRange);
}

- (NSString *)bindingIPAddress
{
  // Existence of USE_IP in the environment allows specifying which interface to bind to
  if (NSProcessInfo.processInfo.environment[@"USE_IP"] &&
      [NSProcessInfo.processInfo.environment[@"USE_IP"] length] > 0) {
    return NSProcessInfo.processInfo.environment[@"USE_IP"];
  }

  return nil;
}

- (NSInteger)mjpegServerPort
{
  NSUInteger portFromArguments = [self.class mjpegServerPortFromArguments];
  if (portFromArguments != NSNotFound) {
    return portFromArguments;
  }

  if (NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] length] > 0) {
    return [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] integerValue];
  }

  return DefaultMjpegServerPort;
}

- (UInt64)httpRequestBodySizeLimit
{
  NSString *limit = NSProcessInfo.processInfo.environment[@"MAX_HTTP_REQUEST_BODY_SIZE"];
  if (limit.length > 0) {
    long long parsedLimit = [limit longLongValue];
    if (parsedLimit > 0) {
      return (UInt64)parsedLimit;
    }
  }

  return DefaultHttpRequestBodySizeLimit;
}

- (BOOL)verboseLoggingEnabled
{
  return [NSProcessInfo.processInfo.environment[@"VERBOSE_LOGGING"] boolValue];
}

- (NSUInteger)maxTypingFrequency
{
  NSNumber *override = self.maxTypingFrequencyOverride;
  if (nil == override) {
    return self.defaultTypingFrequency;
  }
  return override.integerValue <= 0
    ? self.defaultTypingFrequency
    : override.integerValue;
}

- (void)setMaxTypingFrequency:(NSUInteger)value
{
  self.maxTypingFrequencyOverride = @(value);
}

// Works for Simulator and Real devices
- (void)configureDefaultKeyboardPreferences
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

- (void)forceSimulatorSoftwareKeyboardPresence
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

- (FBConfigurationKeyboardPreference)keyboardAutocorrection
{
  return [self keyboardsPreference:FBKeyboardAutocorrectionKey];
}

- (void)setKeyboardAutocorrection:(FBConfigurationKeyboardPreference)preference
{
  [self configureKeyboardsPreference:(preference == FBConfigurationKeyboardPreferenceEnabled)
                     forPreferenceKey:FBKeyboardAutocorrectionKey];
}

- (FBConfigurationKeyboardPreference)keyboardPrediction
{
  return [self keyboardsPreference:FBKeyboardPredictionKey];
}

- (void)setKeyboardPrediction:(FBConfigurationKeyboardPreference)preference
{
  [self configureKeyboardsPreference:(preference == FBConfigurationKeyboardPreferenceEnabled)
                     forPreferenceKey:FBKeyboardPredictionKey];
}

- (void)setSnapshotMaxDepth:(int)maxDepth
{
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey, @(maxDepth));
}

- (int)snapshotMaxDepth
{
  return [FBGetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey) intValue];
}

- (void)setSnapshotMaxChildren:(int)maxChildren
{
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxChildrenKey, @(maxChildren));
}

- (int)snapshotMaxChildren
{
  return [FBGetCustomParameterForElementSnapshot(FBSnapshotMaxChildrenKey) intValue];
}

#if !TARGET_OS_TV
- (BOOL)setScreenshotOrientation:(NSString *)orientation error:(NSError **)error
{
  // Only UIInterfaceOrientationUnknown is over iOS 8. Others are over iOS 2.
  // https://developer.apple.com/documentation/uikit/uiinterfaceorientation/uiinterfaceorientationunknown
  if ([orientation.lowercaseString isEqualToString:@"portrait"]) {
    self.screenshotOrientationStorage = UIInterfaceOrientationPortrait;
  } else if ([orientation.lowercaseString isEqualToString:@"portraitupsidedown"]) {
    self.screenshotOrientationStorage = UIInterfaceOrientationPortraitUpsideDown;
  } else if ([orientation.lowercaseString isEqualToString:@"landscaperight"]) {
    self.screenshotOrientationStorage = UIInterfaceOrientationLandscapeRight;
  } else if ([orientation.lowercaseString isEqualToString:@"landscapeleft"]) {
    self.screenshotOrientationStorage = UIInterfaceOrientationLandscapeLeft;
  } else if ([orientation.lowercaseString isEqualToString:@"auto"]) {
    self.screenshotOrientationStorage = UIInterfaceOrientationUnknown;
  } else {
    return [[FBErrorBuilder.builder withDescriptionFormat:
             @"The orientation value '%@' is not known. Only the following orientation values are supported: " \
             "'auto', 'portrait', 'portraitUpsideDown', 'landscapeRight' and 'landscapeLeft'", orientation]
            buildError:error];
  }
  return YES;
}

- (NSInteger)screenshotOrientation
{
  return self.screenshotOrientationStorage;
}

- (NSString *)humanReadableScreenshotOrientation
{
  switch (self.screenshotOrientationStorage) {
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
    default: break;
  }
  return @"auto";
}
#endif

- (void)resetSessionSettings
{
  self.shouldTerminateApp = YES;
  self.shouldUseCompactResponses = YES;
  self.elementResponseAttributes = @"type,label";
  self.maxTypingFrequencyOverride = @(self.defaultTypingFrequency);
  self.screenshotQuality = 3;
  self.useFirstMatch = NO;
  self.boundElementsByIndex = NO;
  self.acceptAlertButtonSelector = @"";
  self.dismissAlertButtonSelector = @"";
  self.autoClickAlertSelector = @"";
  self.waitForIdleTimeout = 10.;
  self.animationCoolOffTimeout = 2.;
  // 50 should be enough for the majority of the cases. The performance is acceptable for values up to 100.
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxDepthKey, @50);
  FBSetCustomParameterForElementSnapshot(FBSnapshotMaxChildrenKey, @INT_MAX);
  self.useClearTextShortcut = YES;
  self.limitXpathContextScope = YES;
#if !TARGET_OS_TV
  self.screenshotOrientationStorage = UIInterfaceOrientationUnknown;
#endif
}

- (void)setReduceMotionEnabled:(BOOL)isEnabled
{
  Class settingsClass = NSClassFromString(axSettingsClassName);
  AXSettings *settings = (AXSettings *)[settingsClass sharedInstance];

  // Below does not work on real devices because of iOS security model
  //  (lldb) po settings.reduceMotionEnabled = isEnabled
  //  2019-08-21 22:58:19.776165+0900 WebDriverAgentRunner-Runner[322:13361] [User Defaults] Couldn't write value for key ReduceMotionEnabled in CFPrefsPlistSource<0x28111a700> (Domain: com.apple.Accessibility, User: kCFPreferencesCurrentUser, ByHost: No, Container: (null), Contents Need Refresh: No): setting preferences outside an application's container requires user-preference-write or file-write-data sandbox access
  if ([settings respondsToSelector:@selector(setReduceMotionEnabled:)]) {
    [settings setReduceMotionEnabled:isEnabled];
  }
}

- (BOOL)reduceMotionEnabled
{
  Class settingsClass = NSClassFromString(axSettingsClassName);
  AXSettings *settings = (AXSettings *)[settingsClass sharedInstance];

  if ([settings respondsToSelector:@selector(reduceMotionEnabled)]) {
    return settings.reduceMotionEnabled;
  }
  return NO;
}

#pragma mark Private

- (FBConfigurationKeyboardPreference)keyboardsPreference:(nonnull NSString *)key
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

- (void)configureKeyboardsPreference:(BOOL)enable forPreferenceKey:(nonnull NSString *)key
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

@end
