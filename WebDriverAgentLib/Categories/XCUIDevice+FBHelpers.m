/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIDevice+FBHelpers.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#include <notify.h>
#import <objc/runtime.h>

#import "FBErrorBuilder.h"
#import "FBImageUtils.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBScreenshot.h"
#import "FBXCDeviceEvent.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIDevice.h"

static const NSTimeInterval FBHomeButtonCoolOffTime = 1.;
static const NSTimeInterval FBScreenLockTimeout = 5.;

#if TARGET_OS_TV
NSDictionary<NSString *, NSNumber *> *fb_availableButtonNames(void) {
  static dispatch_once_t onceToken;
  static NSDictionary *result;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary *buttons = [NSMutableDictionary dictionary];
    // https://developer.apple.com/design/human-interface-guidelines/remotes
    buttons[@"up"] = @(XCUIRemoteButtonUp);                     // 0
    buttons[@"down"] = @(XCUIRemoteButtonDown);                 // 1
    buttons[@"left"] = @(XCUIRemoteButtonLeft);                 // 2
    buttons[@"right"] = @(XCUIRemoteButtonRight);               // 3
    buttons[@"select"] = @(XCUIRemoteButtonSelect);             // 4
    buttons[@"menu"] = @(XCUIRemoteButtonMenu);                 // 5
    buttons[@"playpause"] = @(XCUIRemoteButtonPlayPause);       // 6
    buttons[@"home"] = @(XCUIRemoteButtonHome);                 // 7
#if __clang_major__ >= 15 // Xcode 15+
    buttons[@"pageup"] = @(XCUIRemoteButtonPageUp);             // 9
    buttons[@"pagedown"] = @(XCUIRemoteButtonPageDown);         // 10
    buttons[@"guide"] = @(XCUIRemoteButtonGuide);               // 11
#endif
#if __clang_major__ >= 17 // likely Xcode 16.3+
    if (@available(tvOS 18.1, *)) {
      buttons[@"fourcolors"] = @(XCUIRemoteButtonFourColors);   // 12
      buttons[@"onetwothree"] = @(XCUIRemoteButtonOneTwoThree); // 13
      buttons[@"tvprovider"] = @(XCUIRemoteButtonTVProvider);   // 14
    }
#endif
    result = [buttons copy];
  });
  return result;
}
#else
NSDictionary<NSString *, NSNumber *> *fb_availableButtonNames(void) {
  static dispatch_once_t onceToken;
  static NSDictionary *result;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary *buttons = [NSMutableDictionary dictionary];
    buttons[@"home"] = @(XCUIDeviceButtonHome);             // 1
#if !TARGET_OS_SIMULATOR
    buttons[@"volumeup"] = @(XCUIDeviceButtonVolumeUp);     // 2
    buttons[@"volumedown"] = @(XCUIDeviceButtonVolumeDown); // 3
#endif
    if (@available(iOS 16.0, *)) {
#if __clang_major__ >= 15 // likely Xcode 15+
      if ([XCUIDevice.sharedDevice hasHardwareButton:XCUIDeviceButtonAction]) {
        buttons[@"action"] = @(XCUIDeviceButtonAction);     // 4
      }
#endif
#if (!TARGET_OS_SIMULATOR && __clang_major__ >= 16) // likely Xcode 16+
      if ([XCUIDevice.sharedDevice hasHardwareButton:XCUIDeviceButtonCamera]) {
        buttons[@"camera"] = @(XCUIDeviceButtonCamera);
      }
#endif
    }
    result = [buttons copy];
  });
  return result;
}
#endif

@implementation XCUIDevice (FBHelpers)

static bool fb_isLocked;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"

+ (void)load
{
  [self fb_registerAppforDetectLockState];
}

#pragma clang diagnostic pop

+ (void)fb_registerAppforDetectLockState
{
  int notify_token;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
  notify_register_dispatch("com.apple.springboard.lockstate", &notify_token, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(int token) {
    uint64_t state = UINT64_MAX;
    notify_get_state(token, &state);
    fb_isLocked = state != 0;
  });
#pragma clang diagnostic pop
}

- (BOOL)fb_goToHomescreenWithError:(NSError **)error
{
  return [XCUIApplication fb_switchToSystemApplicationWithError:error];
}

- (BOOL)fb_lockScreen:(NSError **)error
{
  if (fb_isLocked) {
    return YES;
  }
  [self pressLockButton];
  return [[[[FBRunLoopSpinner new]
            timeout:FBScreenLockTimeout]
           timeoutErrorMessage:@"Timed out while waiting until the screen gets locked"]
          spinUntilTrue:^BOOL{
            return fb_isLocked;
          } error:error];
}

- (BOOL)fb_isScreenLocked
{
  return fb_isLocked;
}

- (BOOL)fb_unlockScreen:(NSError **)error
{
  if (!fb_isLocked) {
    return YES;
  }
  [self pressButton:XCUIDeviceButtonHome];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
#if !TARGET_OS_TV
  [self pressButton:XCUIDeviceButtonHome];
#else
  [self pressButton:XCUIDeviceButtonHome];
#endif
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
  return [[[[FBRunLoopSpinner new]
            timeout:FBScreenLockTimeout]
           timeoutErrorMessage:@"Timed out while waiting until the screen gets unlocked"]
          spinUntilTrue:^BOOL{
            return !fb_isLocked;
          } error:error];
}

- (NSData *)fb_screenshotWithError:(NSError*__autoreleasing*)error
{
  return [FBScreenshot takeInOriginalResolutionWithQuality:FBConfiguration.screenshotQuality
                                                     error:error];
}

- (BOOL)fb_fingerTouchShouldMatch:(BOOL)shouldMatch
{
  const char *name;
  if (shouldMatch) {
    name = "com.apple.BiometricKit_Sim.fingerTouch.match";
  } else {
    name = "com.apple.BiometricKit_Sim.fingerTouch.nomatch";
  }
  return notify_post(name) == NOTIFY_STATUS_OK;
}

- (NSString *)fb_wifiIPAddress
{
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = getifaddrs(&interfaces);
  if (success != 0) {
    freeifaddrs(interfaces);
    return nil;
  }

  NSString *address = nil;
  temp_addr = interfaces;
  while(temp_addr != NULL) {
    if(temp_addr->ifa_addr->sa_family != AF_INET) {
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    NSString *interfaceName = [NSString stringWithUTF8String:temp_addr->ifa_name];
    if(![interfaceName isEqualToString:@"en0"]) {
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
    break;
  }
  freeifaddrs(interfaces);
  return address;
}

- (BOOL)fb_openUrl:(NSString *)url error:(NSError **)error
{
  NSURL *parsedUrl = [NSURL URLWithString:url];
  if (nil == parsedUrl) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"'%@' is not a valid URL", url]
            buildError:error];
  }

  NSError *err;
  if ([FBXCTestDaemonsProxy openDefaultApplicationForURL:parsedUrl error:&err]) {
    return YES;
  }
  if (![err.description containsString:@"does not support"]) {
    if (error) {
      *error = err;
    }
    return NO;
  }

  id siriService = [self valueForKey:@"siriService"];
  if (nil != siriService) {
    return [self fb_activateSiriVoiceRecognitionWithText:[NSString stringWithFormat:@"Open {%@}", url] error:error];
  }

  NSString *description = [NSString stringWithFormat:@"Cannot open '%@' with the default application assigned for it. Consider upgrading to Xcode 14.3+/iOS 16.4+", url];
  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"%@", description]
          buildError:error];;
}

- (BOOL)fb_openUrl:(NSString *)url withApplication:(NSString *)bundleId error:(NSError **)error
{
  NSURL *parsedUrl = [NSURL URLWithString:url];
  if (nil == parsedUrl) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"'%@' is not a valid URL", url]
            buildError:error];
  }

  return [FBXCTestDaemonsProxy openURL:parsedUrl usingApplication:bundleId error:error];
}

- (BOOL)fb_activateSiriVoiceRecognitionWithText:(NSString *)text error:(NSError **)error
{
  id siriService = [self valueForKey:@"siriService"];
  if (nil == siriService) {
    return [[[FBErrorBuilder builder]
             withDescription:@"Siri service is not available on the device under test"]
            buildError:error];
  }
  SEL selector = NSSelectorFromString(@"activateWithVoiceRecognitionText:");
  NSMethodSignature *signature = [siriService methodSignatureForSelector:selector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
  [invocation setSelector:selector];
  [invocation setArgument:&text atIndex:2];
  @try {
    [invocation invokeWithTarget:siriService];
    return YES;
  } @catch (NSException *e) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"%@", e.reason]
            buildError:error];
  }
}

- (BOOL)fb_hasButton:(NSString *)buttonName
{
  return fb_availableButtonNames()[buttonName.lowercaseString] != nil;
}

- (BOOL)fb_pressButton:(NSString *)buttonName
           forDuration:(nullable NSNumber *)duration
                 error:(NSError **)error
{
#if !TARGET_OS_TV
  return [self fb_pressButton:buttonName error:error];
#else

  NSDictionary<NSString *, NSNumber *> *availableButtons = fb_availableButtonNames();
  NSNumber *buttonValue = availableButtons[buttonName.lowercaseString];
  
  if (!buttonValue) {
    NSArray *sortedKeys = [availableButtons.allKeys sortedArrayUsingSelector:@selector(compare:)];
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The button '%@' is not supported. The device under test only supports the following buttons: %@", buttonName, sortedKeys]
            buildError:error];
  }
  if (duration) {
    // https://developer.apple.com/documentation/xcuiautomation/xcuiremote/press(_:forduration:)
    [[XCUIRemote sharedRemote] pressButton:(XCUIRemoteButton)[buttonValue unsignedIntegerValue] forDuration:duration.doubleValue];
  } else {
    // https://developer.apple.com/documentation/xcuiautomation/xcuiremote/press(_:)
    [[XCUIRemote sharedRemote] pressButton:(XCUIRemoteButton)[buttonValue unsignedIntegerValue]];
  }
  return YES;
#endif
}

#if !TARGET_OS_TV
- (BOOL)fb_pressButton:(NSString *)buttonName
                 error:(NSError **)error
{
  NSDictionary<NSString *, NSNumber *> *availableButtons = fb_availableButtonNames();
  NSNumber *buttonValue = availableButtons[buttonName.lowercaseString];
  
  if (!buttonValue) {
    NSArray *sortedKeys = [availableButtons.allKeys sortedArrayUsingSelector:@selector(compare:)];
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The button '%@' is not supported. The device under test only supports the following buttons: %@", buttonName, sortedKeys]
            buildError:error];
  }
  [self pressButton:(XCUIDeviceButton)[buttonValue unsignedIntegerValue]];
  return YES;
}
#endif

- (BOOL)fb_performIOHIDEventWithPage:(unsigned int)page
                               usage:(unsigned int)usage
                            duration:(NSTimeInterval)duration
                               error:(NSError **)error
{
  id<FBXCDeviceEvent> event = FBCreateXCDeviceEvent(page, usage, duration, error);
  return nil == event ? NO : [self performDeviceEvent:event error:error];
}

- (BOOL)fb_setAppearance:(FBUIInterfaceAppearance)appearance error:(NSError **)error
{
  SEL selector = NSSelectorFromString(@"setAppearanceMode:");
  if (nil != selector && [self respondsToSelector:selector]) {
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:self];
    [invocation setArgument:&appearance atIndex:2];
    [invocation invoke];
    return YES;
  }

#if __clang_major__ >= 15 || (__clang_major__ >= 14 && __clang_minor__ >= 0 && __clang_patchlevel__ >= 3)
  // Xcode 14.3.1 can build these values.
  // For iOS 17+
  if ([self respondsToSelector:NSSelectorFromString(@"appearance")]) {
    self.appearance = (XCUIDeviceAppearance) appearance;
    return YES;
  }
#endif

  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"Current Xcode SDK does not support appearance changing"]
          buildError:error];
}

- (NSNumber *)fb_getAppearance
{
#if __clang_major__ >= 15 || (__clang_major__ >= 14 && __clang_minor__ >= 0 && __clang_patchlevel__ >= 3)
  // Xcode 14.3.1 can build these values.
  // For iOS 17+
  if ([self respondsToSelector:NSSelectorFromString(@"appearance")]) {
    return [NSNumber numberWithLongLong:[self appearance]];
  }
#endif

  return [self respondsToSelector:@selector(appearanceMode)]
  ? [NSNumber numberWithLongLong:[self appearanceMode]]
  : nil;
}

#if !TARGET_OS_TV
- (BOOL)fb_setSimulatedLocation:(CLLocation *)location error:(NSError **)error
{
  return [FBXCTestDaemonsProxy setSimulatedLocation:location error:error];
}

- (nullable CLLocation *)fb_getSimulatedLocation:(NSError **)error
{
  return [FBXCTestDaemonsProxy getSimulatedLocation:error];
}

- (BOOL)fb_clearSimulatedLocation:(NSError **)error
{
  return [FBXCTestDaemonsProxy clearSimulatedLocation:error];
}
#endif

@end
