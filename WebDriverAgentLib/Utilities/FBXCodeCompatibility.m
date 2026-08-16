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

NSInteger FBTestmanagerdVersion(void)
{
  static dispatch_once_t getTestmanagerdVersion;
  static NSInteger testmanagerdVersion;
  dispatch_once(&getTestmanagerdVersion, ^{
    id<XCTMessagingChannel_RunnerToDaemon> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    if ([(NSObject *)proxy respondsToSelector:@selector(_XCT_exchangeProtocolVersion:reply:)]) {
      id<FBXCTestManagerLegacyProtocolVersionExchanging> legacyProxy = (id<FBXCTestManagerLegacyProtocolVersionExchanging>)proxy;
      [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
        [legacyProxy _XCT_exchangeProtocolVersion:testmanagerdVersion reply:^(unsigned long long code) {
          testmanagerdVersion = (NSInteger) code;
          completion();
        }];
      }];
    } else {
      // Modern testmanagerd (Xcode 15+) has already negotiated named XCTCapabilities by the time
      // a daemon session exists, instead of a single scalar protocol version. There is no direct
      // integer equivalent to report here (this value is diagnostic-only, surfaced via the
      // 'testmanagerdVersion' session capability), so keep reporting the existing "assume
      // newest/full-featured" sentinel, while confirming capabilities did negotiate successfully.
      XCTCapabilities *capabilities = [XCTRunnerDaemonSession sharedSession].remoteInterfaceCapabilities;
      if (nil == capabilities) {
        [FBLogger log:@"Could not retrieve testmanagerd capabilities"];
      }
      testmanagerdVersion = 0xFFFF;
    }
  });
  return testmanagerdVersion;
}
