/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBConfiguration.h"

@interface FBConfigurationTests : XCTestCase

@end

@implementation FBConfigurationTests

- (void)setUp
{
  [super setUp];
  unsetenv("USE_PORT");
  unsetenv("USE_IP");
  unsetenv("VERBOSE_LOGGING");
  unsetenv("MAX_HTTP_REQUEST_BODY_SIZE");
}

- (void)testBindingPortDefault
{
  XCTAssertTrue(NSEqualRanges(FBConfiguration.sharedInstance.bindingPortRange, NSMakeRange(8100, 100)));
}

- (void)testBindingPortEnvironmentOverwrite
{
  setenv("USE_PORT", "1000", 1);
  XCTAssertTrue(NSEqualRanges(FBConfiguration.sharedInstance.bindingPortRange, NSMakeRange(1000, 1)));
}

- (void)testVerboseLoggingDefault
{
  XCTAssertFalse(FBConfiguration.sharedInstance.verboseLoggingEnabled);
}

- (void)testVerboseLoggingEnvironmentOverwrite
{
  setenv("VERBOSE_LOGGING", "YES", 1);
  XCTAssertTrue(FBConfiguration.sharedInstance.verboseLoggingEnabled);
}

- (void)testBindingIPDefault
{
  XCTAssertNil(FBConfiguration.sharedInstance.bindingIPAddress);
}

- (void)testBindingIPEnvironmentOverwrite
{
  setenv("USE_IP", "192.168.1.100", 1);
  XCTAssertEqualObjects(FBConfiguration.sharedInstance.bindingIPAddress, @"192.168.1.100");
}

- (void)testHttpRequestBodySizeLimitDefault
{
  XCTAssertEqual(FBConfiguration.sharedInstance.httpRequestBodySizeLimit, 1024ull * 1024ull * 1024ull);
}

- (void)testHttpRequestBodySizeLimitEnvironmentOverwrite
{
  setenv("MAX_HTTP_REQUEST_BODY_SIZE", "1024", 1);
  XCTAssertEqual(FBConfiguration.sharedInstance.httpRequestBodySizeLimit, 1024ull);
}

@end
