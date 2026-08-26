/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCodeCompatibility.h"

#import "FBXCAXClientProxy.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElementQuery.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTCapabilities.h"
#import "XCTMessagingChannel_RunnerToDaemon-Protocol.h"
#import "XCTRunnerDaemonSession.h"

/**
 Legacy testmanagerd (pre-Xcode 15) protocol-version handshake. Xcode 15+ testmanagerd replaced
 this with named XCTCapabilities negotiation and no longer declares this selector at all, so it
 does not appear in the modern XCTMessagingChannel_RunnerToDaemon protocol surface.
 */
@protocol FBXCTestManagerLegacyProtocolVersionExchanging <NSObject>
- (void)_XCT_exchangeProtocolVersion:(unsigned long long)version reply:(void (^)(unsigned long long code))reply;
@end

@implementation XCUIElementQuery (FBCompatibility)

- (id<FBXCElementSnapshot>)fb_uniqueSnapshotWithError:(NSError **)error
{
  return (id<FBXCElementSnapshot>)[self uniqueMatchingSnapshotWithError:error];
}

- (XCUIElement *)fb_firstMatch
{
  if (FBConfiguration.sharedInstance.useFirstMatch) {
    XCUIElement* match = self.firstMatch;
    return [match exists] ? match : nil;
  }
  return self.fb_allMatches.firstObject;
}

- (NSArray<XCUIElement *> *)fb_allMatches
{
  return FBConfiguration.sharedInstance.boundElementsByIndex
    ? self.allElementsBoundByIndex
    : self.allElementsBoundByAccessibilityElement;
}

@end


@implementation XCUIElement (FBCompatibility)

- (XCUIElementQuery *)fb_query
{
  return self.query;
}

@end

@implementation XCPointerEvent (FBXcodeCompatibility)

+ (BOOL)fb_areKeyEventsSupported
{
  static BOOL isKbInputSupported = NO;
  static dispatch_once_t onceKbInputSupported;
  dispatch_once(&onceKbInputSupported, ^{
    isKbInputSupported = [XCPointerEvent.class respondsToSelector:@selector(keyboardEventForKeyCode:keyPhase:modifierFlags:offset:)];
  });
  return isKbInputSupported;
}

@end

#define TESTMANAGERD_VERSION_TIMEOUT_SEC 20

NSInteger FBTestmanagerdVersion(void)
{
  // -1 means "not yet determined". The timeout fallback is cached like any other outcome: the
  // value is diagnostic-only, and retrying would stall every later /status for the full timeout
  // against a daemon that never answers.
  static NSInteger cachedVersion = -1;
  static dispatch_queue_t syncQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    syncQueue = dispatch_queue_create("com.facebook.wda.testmanagerdVersion", DISPATCH_QUEUE_SERIAL);
  });

  __block NSInteger result;
  dispatch_sync(syncQueue, ^{
    if (cachedVersion >= 0) {
      result = cachedVersion;
      return;
    }

    id<XCTMessagingChannel_RunnerToDaemon> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    if ([(NSObject *)proxy respondsToSelector:@selector(_XCT_exchangeProtocolVersion:reply:)]) {
      id<FBXCTestManagerLegacyProtocolVersionExchanging> legacyProxy = (id<FBXCTestManagerLegacyProtocolVersionExchanging>)proxy;
      __block NSInteger receivedVersion = -1;
      dispatch_semaphore_t sem = dispatch_semaphore_create(0);
      [legacyProxy _XCT_exchangeProtocolVersion:0 reply:^(unsigned long long code) {
        receivedVersion = (NSInteger) code;
        dispatch_semaphore_signal(sem);
      }];
      int64_t timeoutNs = (int64_t)(TESTMANAGERD_VERSION_TIMEOUT_SEC * NSEC_PER_SEC);
      if (0 != dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNs))) {
        [FBLogger logFmt:@"Did not receive a testmanagerd protocol version reply within %d seconds; assuming the newest/full-featured protocol", TESTMANAGERD_VERSION_TIMEOUT_SEC];
        result = 0xFFFF;
      } else {
        result = receivedVersion;
      }
    } else {
      // Modern testmanagerd (Xcode 15+) negotiates named XCTCapabilities instead of a scalar
      // version; there's no direct integer equivalent, so just confirm capabilities negotiated.
      XCTCapabilities *capabilities = [XCTRunnerDaemonSession sharedSession].remoteInterfaceCapabilities;
      if (nil == capabilities) {
        [FBLogger log:@"Could not retrieve testmanagerd capabilities"];
      }
      result = 0xFFFF;
    }
    cachedVersion = result;
  });
  return result;
}
