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

#import "FBRuntimeUtils.h"

@interface FBRuntimeUtilsTests : FBIntegrationTestCase

@end

@implementation FBRuntimeUtilsTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)testLowMemoryWarning
{
  NSError *error;
  XCTAssertTrue(FBSimuteLowMemoryWarning(&error));
  XCTAssertNil(error);
}

@end
