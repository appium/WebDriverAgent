/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBConfiguration.h"
#import "FBScreen.h"
#import "FBScreenshot.h"
#import "XCUIScreen.h"

@interface FBScreenTests : FBIntegrationTestCase
@end

@implementation FBScreenTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)tearDown
{
  FBConfiguration.sharedInstance.currentDisplayId = nil;
  [super tearDown];
}

- (void)testDisplayID
{
  XCTAssertGreaterThanOrEqual([FBScreen displayID], 0LL);
}

- (void)testScreens
{
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *screens = [FBScreen screensWithError:&error];

  XCTAssertNotNil(screens);
  XCTAssertNil(error);
  XCTAssertGreaterThan(screens.count, 0UL);

  NSDictionary<NSString *, id> *mainScreen = nil;
  for (NSDictionary<NSString *, id> *screen in screens) {
    if ([screen[@"isMain"] boolValue]) {
      mainScreen = screen;
      break;
    }
  }
  XCTAssertNotNil(mainScreen);
  XCTAssertEqualObjects(mainScreen[@"displayId"], @([FBScreen displayID]));
  XCTAssertNotNil(mainScreen[@"scale"]);
  XCTAssertNotNil(mainScreen[@"bounds"]);
  XCTAssertNotNil(mainScreen[@"traits"]);
}

- (void)testScreenWithDisplayID
{
  NSError *error = nil;
  XCUIScreen *screen = [FBScreen screenWithDisplayID:[FBScreen displayID] error:&error];
  XCTAssertNil(error);
  XCTAssertEqual(screen.displayID, [FBScreen displayID]);

  XCTAssertNil([FBScreen screenWithDisplayID:[self unknownDisplayID] error:&error]);
  XCTAssertNotNil(error);
}

- (void)testCurrentScreenDefaultsToMainScreen
{
  NSError *error = nil;
  XCTAssertTrue([FBScreen currentScreenWithError:&error].isMainScreen);
  XCTAssertNil(error);
}

- (void)testCurrentScreenFollowsSetting
{
  FBConfiguration.sharedInstance.currentDisplayId = @([FBScreen displayID]);
  NSError *error = nil;
  XCTAssertEqual([FBScreen currentScreenWithError:&error].displayID, [FBScreen displayID]);
  XCTAssertNil(error);
  XCTAssertNotNil([FBScreenshot takeInOriginalResolutionWithQuality:0 error:&error]);
  XCTAssertNil(error);

  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  XCTAssertNil([FBScreen currentScreenWithError:&error]);
  XCTAssertNotNil(error);
  error = nil;
  XCTAssertNil([FBScreenshot takeInOriginalResolutionWithQuality:0 error:&error]);
  XCTAssertNotNil(error);
}

- (void)testSessionResetClearsCurrentDisplay
{
  FBConfiguration.sharedInstance.currentDisplayId = @([FBScreen displayID]);
  [FBConfiguration.sharedInstance resetSessionSettings];
  XCTAssertNil(FBConfiguration.sharedInstance.currentDisplayId);
}

- (long long)unknownDisplayID
{
  long long maxID = 0;
  for (NSDictionary<NSString *, id> *screen in [FBScreen screensWithError:nil]) {
    maxID = MAX(maxID, [screen[@"displayId"] longLongValue]);
  }
  return maxID + 1;
}

- (void)testScreenScale
{
  XCTAssertTrue([FBScreen scale] >= 2);
}

@end
