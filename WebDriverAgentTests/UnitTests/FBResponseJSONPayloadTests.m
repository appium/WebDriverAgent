/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBResponseJSONPayload.h"
#import "RouteResponse.h"

@interface FBResponseJSONPayloadTests : XCTestCase
@end

@implementation FBResponseJSONPayloadTests

// https://github.com/appium/appium/issues/22673
- (void)testDispatchSanitizesNonUtf8EncodableStrings
{
  unichar chars[] = {'a', 'b', 'c', 0xD800, 'd', 'e', 'f'};
  NSString *unsafe = [NSString stringWithCharacters:chars length:sizeof(chars) / sizeof(unichar)];
  NSDictionary *dictionary = @{@"value": unsafe};
  FBResponseJSONPayload *payload = [[FBResponseJSONPayload alloc] initWithDictionary:dictionary
                                                                        httpStatusCode:kHTTPStatusCodeOK];
  RouteResponse *response = [RouteResponse new];

  XCTAssertNoThrow([payload dispatchWithResponse:response]);
  XCTAssertNotNil(response.responseData);

  NSError *error = nil;
  NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:response.responseData
                                                           options:0
                                                             error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(parsed[@"value"], @"abc�def");
}

// Dictionary keys must be sanitized too, not just values
- (void)testDispatchSanitizesNonUtf8EncodableKeys
{
  unichar chars[] = {'k', 0xD800, 'y'};
  NSString *unsafeKey = [NSString stringWithCharacters:chars length:sizeof(chars) / sizeof(unichar)];
  NSDictionary *dictionary = @{unsafeKey: @"value"};
  FBResponseJSONPayload *payload = [[FBResponseJSONPayload alloc] initWithDictionary:dictionary
                                                                        httpStatusCode:kHTTPStatusCodeOK];
  RouteResponse *response = [RouteResponse new];

  XCTAssertNoThrow([payload dispatchWithResponse:response]);
  XCTAssertNotNil(response.responseData);

  NSError *error = nil;
  NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:response.responseData
                                                           options:0
                                                             error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(parsed[@"k�y"], @"value");
}

- (void)testDispatchWithRegularDictionary
{
  NSDictionary *dictionary = @{@"value": @"regular string"};
  FBResponseJSONPayload *payload = [[FBResponseJSONPayload alloc] initWithDictionary:dictionary
                                                                        httpStatusCode:kHTTPStatusCodeOK];
  RouteResponse *response = [RouteResponse new];

  [payload dispatchWithResponse:response];

  NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:response.responseData
                                                           options:0
                                                             error:nil];
  XCTAssertEqualObjects(parsed, dictionary);
}

@end
