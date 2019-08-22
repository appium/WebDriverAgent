//
//  FBConfigurationTestCase.m
//  IntegrationTests_2
//
//  Created by Kazuaki Matsuo on 2019/08/22.
//  Copyright © 2019 Facebook. All rights reserved.
//

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
  if (isSDKVersionLessThan(@"10.0")) {
    XCTAssertEqual([FBConfiguration reduceMotionEnabled], NO);
  } else {
    XCTAssertEqual([FBConfiguration reduceMotionEnabled], YES);
  }

  [FBConfiguration setReduceMotionEnabled:defaultReduceMotionEnabled];
  if (isSDKVersionLessThan(@"10.0")) {
    XCTAssertEqual([FBConfiguration reduceMotionEnabled], NO);
  } else {
    XCTAssertEqual([FBConfiguration reduceMotionEnabled], defaultReduceMotionEnabled);
  }
}

@end
