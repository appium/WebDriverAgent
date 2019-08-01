/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIDevice+FBHelpers.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#include <notify.h>
#import <objc/runtime.h>

#import "FBSpringboardApplication.h"
#import "FBErrorBuilder.h"
#import "FBImageUtils.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBXCodeCompatibility.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import "XCUIDevice.h"
#import "XCUIScreen.h"

static const NSTimeInterval FBHomeButtonCoolOffTime = 1.;
static const NSTimeInterval FBScreenLockTimeout = 5.;
static const NSTimeInterval SCREENSHOT_TIMEOUT = 2;

@implementation XCUIDevice (FBHelpers)

static bool fb_isLocked;

+ (void)load
{
  [self fb_registerAppforDetectLockState];
}

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
  [self pressButton:XCUIDeviceButtonHome];
  // This is terrible workaround to the fact that pressButton:XCUIDeviceButtonHome is not a synchronous action.
  // On 9.2 some first queries  will trigger additional "go to home" event
  // So if we don't wait here it will be interpreted as double home button gesture and go to application switcher instead.
  // On 9.3 pressButton:XCUIDeviceButtonHome can be slightly delayed.
  // Causing waitUntilApplicationBoardIsVisible not to work properly in some edge cases e.g. like starting session right after this call, while being on home screen
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
  if (![[FBSpringboardApplication fb_springboard] fb_waitUntilApplicationBoardIsVisible:error]) {
    return NO;
  }
  return YES;
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
  if (SYSTEM_VERSION_LESS_THAN(@"10.0")) {
    [[FBApplication fb_activeApplication] swipeRight];
  } else {
    [self pressButton:XCUIDeviceButtonHome];
  }
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
  NSData* screenshotData = [self fb_rawScreenshotWithQuality:FBConfiguration.screenshotQuality error:error];
  if (nil == screenshotData) {
    return nil;
  }
#if TARGET_OS_TV
  return FBAdjustScreenshotOrientationForApplication(screenshotData);
#else
  return FBAdjustScreenshotOrientationForApplication(screenshotData, FBApplication.fb_activeApplication.interfaceOrientation);
#endif
}

- (NSData *)fb_rawScreenshotWithQuality:(NSUInteger)quality error: (NSError*__autoreleasing*) error
{
  if ([XCUIDevice fb_isNewScreenshotAPISupported]) {
    return [XCUIScreen.mainScreen screenshotDataForQuality:quality rect:CGRectNull error:error];
  } else {
    id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    __block NSData *screenshotData = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [proxy _XCT_requestScreenshotWithReply:^(NSData *data, NSError *screenshotError) {
      screenshotData = data;
      *error = screenshotError;
      dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
    return screenshotData;
  }
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

+ (BOOL)fb_isNewScreenshotAPISupported
{
  static dispatch_once_t newScreenshotAPISupported;
  static BOOL result;
  dispatch_once(&newScreenshotAPISupported, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
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
    if(![interfaceName containsString:@"en"]) {
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

  id siriService = [self valueForKey:@"siriService"];
  if (nil != siriService) {
    return [self fb_activateSiriVoiceRecognitionWithText:[NSString stringWithFormat:@"Open {%@}", url] error:error];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // The link never gets opened by this method: https://forums.developer.apple.com/thread/25355
  if (![[UIApplication sharedApplication] openURL:parsedUrl]) {
#pragma clang diagnostic pop
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The URL %@ cannot be opened", url]
            buildError:error];
  }
  return YES;
}

- (BOOL)fb_activateSiriVoiceRecognitionWithText:(NSString *)text error:(NSError **)error
{
  id siriService = [self valueForKey:@"siriService"];
  if (nil == siriService) {
    return [[[FBErrorBuilder builder]
             withDescription:@"Siri service is not available on the device under test"]
            buildError:error];
  }
  @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [siriService performSelector:NSSelectorFromString(@"activateWithVoiceRecognitionText:")
                      withObject:text];
#pragma clang diagnostic pop
    return YES;
  } @catch (NSException *e) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"%@", e.reason]
            buildError:error];
  }
}

#if TARGET_OS_TV
- (BOOL)fb_pressButton:(NSString *)buttonName error:(NSError **)error
{
  NSMutableArray<NSString *> *supportedButtonNames = [NSMutableArray array];
  NSInteger remoteButton = -1; // no remote button
  if ([buttonName.lowercaseString isEqualToString:@"home"]) {
    //  XCUIRemoteButtonHome        = 7
    remoteButton = XCUIRemoteButtonHome;
  }
  [supportedButtonNames addObject:@"home"];

  // https://developer.apple.com/design/human-interface-guidelines/tvos/remote-and-controllers/remote/
  if ([buttonName.lowercaseString isEqualToString:@"up"]) {
    //  XCUIRemoteButtonUp          = 0,
    remoteButton = XCUIRemoteButtonUp;
  }
  [supportedButtonNames addObject:@"up"];

  if ([buttonName.lowercaseString isEqualToString:@"down"]) {
    //  XCUIRemoteButtonDown        = 1,
    remoteButton = XCUIRemoteButtonDown;
  }
  [supportedButtonNames addObject:@"down"];

  if ([buttonName.lowercaseString isEqualToString:@"left"]) {
    //  XCUIRemoteButtonLeft        = 2,
    remoteButton = XCUIRemoteButtonLeft;
  }
  [supportedButtonNames addObject:@"left"];

  if ([buttonName.lowercaseString isEqualToString:@"right"]) {
    //  XCUIRemoteButtonRight       = 3,
    remoteButton = XCUIRemoteButtonRight;
  }
  [supportedButtonNames addObject:@"right"];

  if ([buttonName.lowercaseString isEqualToString:@"menu"]) {
    //  XCUIRemoteButtonMenu        = 5,
    remoteButton = XCUIRemoteButtonMenu;
  }
  [supportedButtonNames addObject:@"menu"];

  if ([buttonName.lowercaseString isEqualToString:@"playpause"]) {
    //  XCUIRemoteButtonPlayPause   = 6,
    remoteButton = XCUIRemoteButtonPlayPause;
  }
  [supportedButtonNames addObject:@"playpause"];

  if ([buttonName.lowercaseString isEqualToString:@"select"]) {
    //  XCUIRemoteButtonSelect      = 4,
    remoteButton = XCUIRemoteButtonSelect;
  }
  [supportedButtonNames addObject:@"select"];

  if (remoteButton == -1) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The button '%@' is unknown. Only the following button names are supported: %@", buttonName, supportedButtonNames]
            buildError:error];
  }
  [[XCUIRemote sharedRemote] pressButton:remoteButton];
  return YES;
}
#else

- (BOOL)fb_pressButton:(NSString *)buttonName error:(NSError **)error
{
  NSMutableArray<NSString *> *supportedButtonNames = [NSMutableArray array];
  XCUIDeviceButton dstButton = 0;
  if ([buttonName.lowercaseString isEqualToString:@"home"]) {
    dstButton = XCUIDeviceButtonHome;
  }
  [supportedButtonNames addObject:@"home"];
#if !TARGET_OS_SIMULATOR
  if ([buttonName.lowercaseString isEqualToString:@"volumeup"]) {
    dstButton = XCUIDeviceButtonVolumeUp;
  }
  if ([buttonName.lowercaseString isEqualToString:@"volumedown"]) {
    dstButton = XCUIDeviceButtonVolumeDown;
  }
  [supportedButtonNames addObject:@"volumeUp"];
  [supportedButtonNames addObject:@"volumeDown"];
#endif

  if (dstButton == 0) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The button '%@' is unknown. Only the following button names are supported: %@", buttonName, supportedButtonNames]
            buildError:error];
  }
  [self pressButton:dstButton];
  return YES;
}
#endif

@end
