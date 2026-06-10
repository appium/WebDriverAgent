/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBMacros.h"
#import "FBTestMacros.h"
#import "XCUIDevice+FBVoiceOver.h"

@interface FBVoiceOverTests : FBIntegrationTestCase
@end

@implementation FBVoiceOverTests

- (void)tearDown
{
  if ([XCUIDevice.sharedDevice fb_isVoiceOverServiceAvailable]) {
    NSError *error = nil;
    if ([XCUIDevice.sharedDevice fb_isVoiceOverEnabled:&error] && nil == error) {
      [XCUIDevice.sharedDevice fb_disableVoiceOver:&error];
    }
  }
  [super tearDown];
}

- (void)testVoiceOverUnavailableOnOlderSDK
{
  if ([XCUIDevice.sharedDevice fb_isVoiceOverServiceAvailable]) {
    return;
  }

  NSError *error = nil;
  XCTAssertFalse([XCUIDevice.sharedDevice fb_enableVoiceOver:&error]);
  XCTAssertNotNil(error);
  XCTAssertTrue([error.localizedDescription containsString:@"iOS 27"]);
}

- (void)testVoiceOverEnableDisableAndNavigation
{
  if (SYSTEM_VERSION_LESS_THAN(@"27.0")) {
    return;
  }
  if (![XCUIDevice.sharedDevice fb_isVoiceOverServiceAvailable]) {
    return;
  }

  [self launchApplication];

  NSError *error = nil;
  XCTAssertTrue([XCUIDevice.sharedDevice fb_enableVoiceOver:&error]);
  XCTAssertNil(error);
  XCTAssertTrue([XCUIDevice.sharedDevice fb_isVoiceOverEnabled:&error]);
  XCTAssertNil(error);

  NSString *utterance = [XCUIDevice.sharedDevice fb_voiceOverMove:@"forward" error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(utterance);
  XCTAssertTrue(utterance.length > 0);

  NSString *currentSpeech = [XCUIDevice.sharedDevice fb_voiceOverCurrentSpeech:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(currentSpeech);
  XCTAssertEqualObjects(currentSpeech, utterance);

  XCTAssertTrue([XCUIDevice.sharedDevice fb_disableVoiceOver:&error]);
  XCTAssertNil(error);
  XCTAssertFalse([XCUIDevice.sharedDevice fb_isVoiceOverEnabled:&error]);
  XCTAssertNil(error);
}

#if TARGET_OS_IOS
- (void)testVoiceOverMoveBackward
{
  if (SYSTEM_VERSION_LESS_THAN(@"27.0")) {
    return;
  }
  if (![XCUIDevice.sharedDevice fb_isVoiceOverServiceAvailable]) {
    return;
  }

  [self launchApplication];

  NSError *error = nil;
  XCTAssertTrue([XCUIDevice.sharedDevice fb_enableVoiceOver:&error]);
  XCTAssertNil(error);

  XCTAssertNotNil([XCUIDevice.sharedDevice fb_voiceOverMove:@"forward" error:&error]);
  XCTAssertNil(error);

  NSString *utterance = [XCUIDevice.sharedDevice fb_voiceOverMove:@"backward" error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(utterance);
  XCTAssertTrue(utterance.length > 0);
}
#endif

@end
