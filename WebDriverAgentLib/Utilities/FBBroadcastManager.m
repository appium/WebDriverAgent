/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBroadcastManager.h"

#include <time.h>
#import <UIKit/UIKit.h>

#import "FBBroadcastControlServer.h"
#import "FBBroadcastPickerHost.h"
#import "FBBroadcastProtocol.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBRunLoopSpinner.h"
#import "FBUnattachedAppLauncher.h"
#import "FBVideoStreamManager.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"

NSErrorDomain const FBBroadcastManagerErrorDomain = @"com.facebook.WebDriverAgent.FBBroadcastManager";

#if !TARGET_OS_SIMULATOR && !TARGET_OS_TV
static const NSTimeInterval FOREGROUND_TIMEOUT = 5.0;
static const NSTimeInterval CONFIRM_BUTTON_TIMEOUT = 10.0;
// The picker press is dropped silently by the system when it fires before the scene is fully
// active, so it is re-fired periodically until the confirmation sheet shows up.
static const uint64_t PICKER_RETRIGGER_INTERVAL_MS = 2000;

static uint64_t FBBroadcastNowMs(void)
{
  return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
}
#endif
static const NSTimeInterval STOP_TIMEOUT = 5.0;

@interface FBBroadcastManager () <FBBroadcastControlServerDelegate>

@property (nonatomic, nullable) FBBroadcastControlServer *controlServer;
@property (atomic, nullable, copy) NSDictionary *helloInfo;
@property (atomic, nullable, copy) NSDictionary *lastHeartbeat;
@property (atomic, nullable) NSDate *connectedAt;
@property (atomic, nullable) NSDate *lastHeartbeatAt;
@property (atomic) BOOL paused;

@end

@implementation FBBroadcastManager

+ (instancetype)sharedInstance
{
  static FBBroadcastManager *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (BOOL)isExtensionConnected
{
  return self.controlServer.isExtensionConnected;
}

#pragma mark - Control server lifecycle

- (void)startListening
{
  if (nil != self.controlServer) {
    return;
  }
  uint16_t port = (uint16_t)FBConfiguration.broadcastControlPort;
  FBBroadcastControlServer *server = [[FBBroadcastControlServer alloc] initWithPort:port];
  server.delegate = self;
  NSError *error;
  if (![server startWithError:&error]) {
    [FBLogger logFmt:@"Cannot start the broadcast control server on port %d: %@", port, error.description];
    return;
  }
  self.controlServer = server;
}

- (void)stopListening
{
  [self.controlServer stop];
  self.controlServer = nil;
  [self resetConnectionState];
}

- (void)resetConnectionState
{
  self.helloInfo = nil;
  self.lastHeartbeat = nil;
  self.connectedAt = nil;
  self.lastHeartbeatAt = nil;
  self.paused = NO;
}

#pragma mark - Status

- (NSDictionary *)statusDictionary
{
  NSString *state = @"idle";
  if (self.isExtensionConnected) {
    state = self.paused ? @"paused" : @"connected";
  }
  NSDictionary *heartbeat = self.lastHeartbeat;
  return @{
    @"state": state,
    @"controlPort": @(FBConfiguration.broadcastControlPort),
    @"preferredExtension": FBConfiguration.broadcastExtensionBundleId,
    @"connectedAt": self.connectedAt ? @((uint64_t)(self.connectedAt.timeIntervalSince1970 * 1000)) : NSNull.null,
    @"lastHeartbeatAt": self.lastHeartbeatAt ? @((uint64_t)(self.lastHeartbeatAt.timeIntervalSince1970 * 1000)) : NSNull.null,
    @"hello": self.helloInfo ?: NSNull.null,
    @"heartbeat": heartbeat ?: NSNull.null,
    @"sessions": [FBVideoStreamManager.sharedInstance activeSessionsInfo],
  };
}

#pragma mark - Broadcast start/stop

- (BOOL)startBroadcastWithTimeout:(NSTimeInterval)timeout
              confirmButtonLabels:(NSArray<NSString *> *)confirmButtonLabels
             restoreForegroundApp:(BOOL)restoreForegroundApp
                            error:(NSError **)error
{
#if TARGET_OS_SIMULATOR || TARGET_OS_TV
  if (error) {
    *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                 code:FBBroadcastManagerErrorUnsupported
                             userInfo:@{NSLocalizedDescriptionKey: @"ReplayKit broadcasts are only supported on physical iOS devices"}];
  }
  return NO;
#else
  if (self.isExtensionConnected) {
    return YES;
  }
  if (nil == self.controlServer) {
    [self startListening];
  }

  uint64_t startedMs = FBBroadcastNowMs();
  XCUIApplication *runner = [[XCUIApplication alloc] initWithBundleIdentifier:(NSString *)NSBundle.mainBundle.bundleIdentifier];
  XCUIApplication *previousApp = nil;
  BOOL runnerIsActive = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
  // When the runner is already frontmost there is neither an app to restore nor a need for the
  // (slow) active-app lookup.
  if (restoreForegroundApp && !runnerIsActive) {
    XCUIApplication *active = XCUIApplication.fb_activeApplication;
    if (nil != active && ![active.bundleID isEqualToString:runner.bundleID]) {
      previousApp = active;
    }
    [FBLogger logFmt:@"broadcast/start: active-app lookup finished after %llums", FBBroadcastNowMs() - startedMs];
  }

  // The picker can only present from a foreground app, so bring the runner up first. The
  // LaunchServices route is used instead of XCUIApplication.activate because activating the
  // runner from inside itself blocks on a self-quiescence wait that can only ever time out:
  // the waiting thread is the very main thread whose idleness is being awaited.
  if (!runnerIsActive) {
    BOOL launched = [FBUnattachedAppLauncher launchAppWithBundleId:(NSString *)NSBundle.mainBundle.bundleIdentifier];
    BOOL foregrounded = launched && [[[[FBRunLoopSpinner new] timeout:2.0] interval:0.05] spinUntilTrue:^BOOL{
      return UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    }];
    if (!foregrounded) {
      // Reliable but slow fallback: XCTest's activation waits out its quiescence timeout.
      [FBLogger log:@"broadcast/start: LaunchServices foregrounding failed; falling back to XCUIApplication.activate"];
      [runner activate];
      foregrounded = [[[[FBRunLoopSpinner new] timeout:FOREGROUND_TIMEOUT] interval:0.05] spinUntilTrue:^BOOL{
        return UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
      }];
    }
    if (!foregrounded) {
      if (error) {
        *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                     code:FBBroadcastManagerErrorTimeout
                                 userInfo:@{NSLocalizedDescriptionKey: @"The runner app could not be brought to the foreground to present the broadcast picker"}];
      }
      return NO;
    }
  }
  [FBLogger logFmt:@"broadcast/start: runner foreground after %llums", FBBroadcastNowMs() - startedMs];

  NSError *pickerError;
  if (![FBBroadcastPickerHost triggerPickerWithPreferredExtension:FBConfiguration.broadcastExtensionBundleId
                                                            error:&pickerError]) {
    if (error) {
      *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                   code:FBBroadcastManagerErrorPicker
                               userInfo:@{NSLocalizedDescriptionKey: pickerError.localizedDescription ?: @"Cannot trigger the broadcast picker"}];
    }
    return NO;
  }
  [FBLogger logFmt:@"broadcast/start: picker triggered after %llums", FBBroadcastNowMs() - startedMs];

  // The confirmation sheet is hosted by different processes depending on the iOS version, so
  // look for the confirm button in both the system app and the runner itself.
  NSArray<NSString *> *labels = confirmButtonLabels.count > 0 ? confirmButtonLabels : @[@"Start Broadcast"];
  NSArray<XCUIApplication *> *candidateApps = @[XCUIApplication.fb_systemApplication, runner];
  __block XCUIElement *confirmButton = nil;
  __block uint64_t lastTriggerMs = FBBroadcastNowMs();
  [[[[FBRunLoopSpinner new] timeout:CONFIRM_BUTTON_TIMEOUT] interval:0.25] spinUntilTrue:^BOOL{
    for (XCUIApplication *app in candidateApps) {
      for (NSString *label in labels) {
        XCUIElement *candidate = app.buttons[label];
        if (candidate.exists) {
          confirmButton = candidate;
          return YES;
        }
      }
      XCUIElement *prefixMatch = [app.buttons matchingPredicate:[NSPredicate predicateWithFormat:@"label BEGINSWITH[c] 'Start'"]].firstMatch;
      if (prefixMatch.exists) {
        confirmButton = prefixMatch;
        return YES;
      }
    }
    if (FBBroadcastNowMs() - lastTriggerMs >= PICKER_RETRIGGER_INTERVAL_MS) {
      lastTriggerMs = FBBroadcastNowMs();
      [FBLogger log:@"broadcast/start: confirmation sheet not visible yet; re-triggering the picker"];
      [FBBroadcastPickerHost triggerPickerWithPreferredExtension:FBConfiguration.broadcastExtensionBundleId
                                                           error:nil];
    }
    return NO;
  }];
  if (nil == confirmButton) {
    [FBBroadcastPickerHost dismiss];
    if (error) {
      *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                   code:FBBroadcastManagerErrorTimeout
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The broadcast confirmation sheet did not show a button labeled %@ within %.0fs. Pass 'confirmButtonLabels' if the device language is not English", [labels componentsJoinedByString:@"/"], CONFIRM_BUTTON_TIMEOUT]}];
    }
    return NO;
  }
  [confirmButton tap];
  [FBLogger logFmt:@"broadcast/start: confirmation tapped after %llums", FBBroadcastNowMs() - startedMs];

  // Cover the system's 3-2-1 countdown plus the extension's connect/HELLO round trip.
  BOOL connected = [[[[FBRunLoopSpinner new] timeout:(timeout > 0 ? timeout : 30.0)] interval:0.3] spinUntilTrue:^BOOL{
    return self.isExtensionConnected;
  }];
  [FBLogger logFmt:@"broadcast/start: %@ after %llums", connected ? @"extension connected" : @"extension connect timeout", FBBroadcastNowMs() - startedMs];
  [FBBroadcastPickerHost dismiss];
  if (!connected) {
    if (error) {
      *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                   code:FBBroadcastManagerErrorTimeout
                               userInfo:@{NSLocalizedDescriptionKey: @"The broadcast was confirmed but the extension did not connect in time. Check that the extension is embedded and signed correctly (see docs/broadcast-extension.md)"}];
    }
    return NO;
  }

  if (nil != previousApp) {
    [previousApp activate];
  }
  return YES;
#endif
}

- (BOOL)stopBroadcastWithError:(NSError **)error
{
  if (!self.isExtensionConnected) {
    return YES;
  }
  [self.controlServer sendStopBroadcast];
  BOOL stopped = [[[[FBRunLoopSpinner new] timeout:STOP_TIMEOUT] interval:0.2] spinUntilTrue:^BOOL{
    return !self.isExtensionConnected;
  }];
  if (!stopped) {
    if (error) {
      *error = [NSError errorWithDomain:FBBroadcastManagerErrorDomain
                                   code:FBBroadcastManagerErrorTimeout
                               userInfo:@{NSLocalizedDescriptionKey: @"The broadcast extension did not finish the broadcast in time"}];
    }
    return NO;
  }
  return YES;
}

#pragma mark - Session bridging

+ (NSDictionary *)sessionAddPayloadForConfiguration:(FBScreenCaptureConfiguration *)configuration
{
  return @{
    FBBroadcastKeyWidth: @(configuration.width),
    FBBroadcastKeyHeight: @(configuration.height),
    FBBroadcastKeyCodec: configuration.codec == FBVideoCodecH265 ? FBBroadcastCodecH265 : FBBroadcastCodecH264,
    FBBroadcastKeyBitrate: @(configuration.bitrate),
    FBBroadcastKeyFps: @(configuration.fps),
  };
}

- (void)notifySessionAdded:(FBVideoStreamSession *)session
{
  if (!self.isExtensionConnected) {
    return;
  }
  [self.controlServer sendSessionAdd:(uint32_t)session.identifier
                       configuration:[self.class sessionAddPayloadForConfiguration:session.configuration]];
}

- (void)notifySessionRemoved:(NSUInteger)identifier
{
  if (!self.isExtensionConnected) {
    return;
  }
  [self.controlServer sendSessionRemove:(uint32_t)identifier];
}

- (void)requestKeyFrameForSession:(NSUInteger)identifier
{
  [self.controlServer sendKeyframeRequest:(uint32_t)identifier];
}

#pragma mark - <FBBroadcastControlServerDelegate>

- (void)broadcastServerDidConnect:(NSDictionary<NSString *, id> *)helloInfo
{
  [FBLogger logFmt:@"The broadcast extension connected: %@", helloInfo];
  self.helloInfo = helloInfo;
  self.connectedAt = NSDate.date;
  self.paused = NO;
  // Attach every live capture session to the broadcast source.
  for (FBVideoStreamSession *session in [FBVideoStreamManager.sharedInstance activeSessions]) {
    [self.controlServer sendSessionAdd:(uint32_t)session.identifier
                         configuration:[self.class sessionAddPayloadForConfiguration:session.configuration]];
  }
}

- (void)broadcastServerDidReceiveHeartbeat:(NSDictionary<NSString *, id> *)heartbeat
{
  self.lastHeartbeat = heartbeat;
  self.lastHeartbeatAt = NSDate.date;
  self.paused = [@"paused" isEqualToString:(NSString *)(heartbeat[FBBroadcastKeyState] ?: @"")];
}

- (void)broadcastServerDidReceiveStatus:(NSDictionary<NSString *, id> *)status
{
  NSString *event = status[FBBroadcastKeyEvent];
  [FBLogger logFmt:@"Broadcast status event: %@", status];
  if ([@"paused" isEqualToString:event]) {
    self.paused = YES;
  } else if ([@"resumed" isEqualToString:event]) {
    self.paused = NO;
  }
}

- (void)broadcastServerDidReceiveSessionError:(NSString *)message forSession:(uint32_t)sessionId
{
  [FBLogger logFmt:@"The broadcast extension cannot serve session %u: %@", sessionId, message];
  FBVideoStreamSession *session = [FBVideoStreamManager.sharedInstance sessionWithIdentifier:sessionId];
  [session detachBroadcastSourceAndForceKeyFrame];
}

- (void)broadcastServerDidReceiveParameterSets:(NSData *)parameterSets forSession:(uint32_t)sessionId
{
  FBVideoStreamSession *session = [FBVideoStreamManager.sharedInstance sessionWithIdentifier:sessionId];
  if (nil == session) {
    [self.controlServer sendSessionRemove:sessionId];
    return;
  }
  [session ingestBroadcastParameterSets:parameterSets];
}

- (void)broadcastServerDidReceiveFrame:(NSData *)annexBPictureData
                            isKeyFrame:(BOOL)isKeyFrame
                                 ptsUs:(uint64_t)ptsUs
                           orientation:(uint8_t)orientation
                            forSession:(uint32_t)sessionId
{
  FBVideoStreamSession *session = [FBVideoStreamManager.sharedInstance sessionWithIdentifier:sessionId];
  if (nil == session) {
    // The session is gone (stale extension pipeline); ask the extension to drop it.
    [self.controlServer sendSessionRemove:sessionId];
    return;
  }
  [session ingestBroadcastFrame:annexBPictureData isKeyFrame:isKeyFrame];
}

- (void)broadcastServerDidDisconnect
{
  [FBLogger log:@"The broadcast extension disconnected; reverting sessions to the screenshot source"];
  [self resetConnectionState];
  for (FBVideoStreamSession *session in [FBVideoStreamManager.sharedInstance activeSessions]) {
    [session detachBroadcastSourceAndForceKeyFrame];
  }
}

@end
