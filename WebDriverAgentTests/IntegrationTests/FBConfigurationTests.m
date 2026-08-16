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
  BOOL defaultReduceMotionEnabled = FBConfiguration.sharedInstance.reduceMotionEnabled;

  FBConfiguration.sharedInstance.reduceMotionEnabled = YES;
  XCTAssertTrue(FBConfiguration.sharedInstance.reduceMotionEnabled);

  FBConfiguration.sharedInstance.reduceMotionEnabled = defaultReduceMotionEnabled;
  XCTAssertEqual(FBConfiguration.sharedInstance.reduceMotionEnabled, defaultReduceMotionEnabled);
}

@end
