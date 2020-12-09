/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBProtocolHelpers.h"

@interface FBProtocolHelpersTests : XCTestCase
@end

@implementation FBProtocolHelpersTests

- (void)testValidPrefixedCapsParsing
{
  NSError *error = nil;
  NSDictionary<NSString *, id> *parsedCaps = FBParseCapabilities(@{
    @"firstMatch": @[@{
      @"appium:bundleId": @"com.example.id"
    }]
  }, &error);
  XCTAssertNil(error);
  XCTAssertEqualObjects(parsedCaps[@"bundleId"], @"com.example.id");
}

- (void)testValidPrefixedCapsMerging
{
  NSError *error = nil;
  NSDictionary<NSString *, id> *parsedCaps = FBParseCapabilities(@{
     @"firstMatch": @[@{
       @"bundleId": @"com.example.id"
     }],
     @"alwaysMatch": @{
       @"google:cap": @"super"
     }
   }, &error);
  XCTAssertNil(error);
  XCTAssertEqualObjects(parsedCaps[@"bundleId"], @"com.example.id");
  XCTAssertEqualObjects(parsedCaps[@"google:cap"], @"super");
}

- (void)testEmptyCaps
{
  NSError *error = nil;
  NSDictionary<NSString *, id> *parsedCaps = FBParseCapabilities(@{}, &error);
  XCTAssertNil(error);
  XCTAssertEqual(parsedCaps.count, 0);
}

- (void)testCapsMergingFailure
{
  NSError *error = nil;
  NSDictionary<NSString *, id> *parsedCaps = FBParseCapabilities(@{
    @"firstMatch": @[@{
      @"appium:bundleId": @"com.example.id"
    }],
    @"alwaysMatch": @{
      @"bundleId": @"other"
    }
  }, &error);
  XCTAssertNil(parsedCaps);
  XCTAssertNotNil(error);
}

- (void)testPrefixingStandardCapability
{
  NSError *error = nil;
  NSDictionary<NSString *, id> *parsedCaps = FBParseCapabilities(@{
    @"firstMatch": @[@{
      @"appium:platformName": @"com.example.id"
    }]
  }, &error);
  XCTAssertNil(parsedCaps);
  XCTAssertNotNil(error);
}

@end
