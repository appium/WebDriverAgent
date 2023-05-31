/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "NSDictionary+FBUtf8SafeDictionary.h"

@interface NSDictionaryFBUtf8SafeTests : XCTestCase
@end

@implementation NSDictionaryFBUtf8SafeTests

- (void)testEmptySafeDictConversion
{
  NSDictionary *d = @{};
  XCTAssertEqualObjects(d, d.fb_utf8SafeDictionary);
}

- (void)testNonEmptySafeDictConversion
{
  NSDictionary *d = @{
    @"1": @[@3, @4],
    @"5": @{@"6": @7, @"8": @9},
    @"10": @"11"
  };
  XCTAssertEqualObjects(d, d.fb_utf8SafeDictionary);
}

@end
