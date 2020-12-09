/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import <XCTest/XCTest.h>
#import "FBIntegrationTestCase.h"

#import "FBConfiguration.h"
#import "FBRuntimeUtils.h"

@interface FBConfigurationTests : FBIntegrationTestCase

@end

@implementation FBConfigurationTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)testReduceMotion
{
  BOOL defaultReduceMotionEnabled = [FBConfiguration reduceMotionEnabled];

  [FBConfiguration setReduceMotionEnabled:YES];
  XCTAssertTrue([FBConfiguration reduceMotionEnabled]);

  [FBConfiguration setReduceMotionEnabled:defaultReduceMotionEnabled];
  if (isSDKVersionLessThan(@"10.0")) {
    XCTAssertFalse([FBConfiguration reduceMotionEnabled]);
  } else {
    XCTAssertEqual([FBConfiguration reduceMotionEnabled], defaultReduceMotionEnabled);
  }
}

@end
