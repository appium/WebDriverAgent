/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
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

- (void)testUnpairedSurrogateSanitization
{
  unichar chars[] = {'a', 'b', 'c', 0xD800, 'd', 'e', 'f'};
  NSString *unsafe = [NSString stringWithCharacters:chars length:sizeof(chars) / sizeof(unichar)];
  NSDictionary *d = @{
    @"key": unsafe,
    @"nested": @{@"value": @[unsafe]},
  };
  NSDictionary *safe = d.fb_utf8SafeDictionary;

  NSString *expected = @"abc�def";
  XCTAssertEqualObjects(safe[@"key"], expected);
  XCTAssertEqualObjects(safe[@"nested"][@"value"][0], expected);

  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:safe
                                                     options:0
                                                       error:&error];
  XCTAssertNotNil(jsonData, @"JSON serialization of the sanitized dictionary unexpectedly failed: %@", error);
}

- (void)testUnpairedSurrogateKeySanitization
{
  unichar chars[] = {'k', 0xD800, 'y'};
  NSString *unsafeKey = [NSString stringWithCharacters:chars length:sizeof(chars) / sizeof(unichar)];
  NSDictionary *d = @{unsafeKey: @"value"};
  NSDictionary *safe = d.fb_utf8SafeDictionary;

  XCTAssertEqualObjects(safe[@"k�y"], @"value");

  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:safe
                                                     options:0
                                                       error:&error];
  XCTAssertNotNil(jsonData, @"JSON serialization of the sanitized dictionary unexpectedly failed: %@", error);
}

- (void)testValidSurrogatePairIsPreserved
{
  NSString *emoji = @"a😀b";
  XCTAssertEqualObjects([emoji fb_utf8SafeStringWithReplacement:0xfffd], emoji);
}

@end
