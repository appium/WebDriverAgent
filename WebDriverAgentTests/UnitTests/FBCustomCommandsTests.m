/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBCustomCommands.h"
#import "FBElementCache.h"
#import "FBRouteRequest-Private.h"
#import "FBSession.h"
#import "FBResponsePayload.h"
#import "RouteResponse.h"
#import "XCUIDevice+FBHelpers.h"
#import "Doubles/XCUIElementDouble.h"

#if !TARGET_OS_TV && __clang_major__ >= 15

@interface FBCustomCommands (FBWDATestable)
+ (id<FBResponsePayload>)handleKeyboardInput:(FBRouteRequest *)request;
+ (id<FBResponsePayload>)handleSetSimulatedHingeAngle:(FBRouteRequest *)request;
@end

@interface FBCustomCommandsTests : XCTestCase
@property (nonatomic, strong) FBSession *session;
@end

@implementation FBCustomCommandsTests

- (void)setUp
{
  [super setUp];
  self.session = [FBSession initWithApplication:nil];
}

- (void)tearDown
{
  [self.session kill];
  [super tearDown];
}

- (FBRouteRequest *)requestWithElement:(XCUIElementDouble *)element keys:(NSArray *)keys
{
  // uuid "0" is reserved by handleKeyboardInput: to mean "no element" (use the active application).
  element.wdUID = @"1";
  NSString *uuid = [self.session.elementCache storeElement:(XCUIElement *)element];
  FBRouteRequest *request = [FBRouteRequest routeRequestWithURL:[NSURL URLWithString:@"http://localhost:8100/"]
                                                       parameters:@{@"uuid": uuid}
                                                        arguments:@{@"keys": keys}];
  request.session = self.session;
  return request;
}

- (void)testDictionaryKeyWithConstantNameIsResolved
{
  XCUIElementDouble *element = XCUIElementDouble.new;
  FBRouteRequest *request = [self requestWithElement:element
                                                 keys:@[@{@"key": @"XCUIKeyboardKeyTab"}]];
  [FBCustomCommands handleKeyboardInput:request];
  XCTAssertEqualObjects(element.typedKeys, @[XCUIKeyboardKeyTab]);
}

- (void)testDictionaryKeyWithLiteralCharacterIsPassedThrough
{
  XCUIElementDouble *element = XCUIElementDouble.new;
  FBRouteRequest *request = [self requestWithElement:element
                                                 keys:@[@{@"key": @"a"}]];
  [FBCustomCommands handleKeyboardInput:request];
  XCTAssertEqualObjects(element.typedKeys, @[@"a"]);
}

- (void)testDictionaryKeyWithConstantNameAndModifierFlagsIsResolved
{
  XCUIElementDouble *element = XCUIElementDouble.new;
  FBRouteRequest *request = [self requestWithElement:element
                                                 keys:@[@{@"key": @"XCUIKeyboardKeyTab", @"modifierFlags": @2}]];
  [FBCustomCommands handleKeyboardInput:request];
  XCTAssertEqualObjects(element.typedKeys, @[XCUIKeyboardKeyTab]);
  XCTAssertEqual(element.lastTypedModifierFlags, 2);
}

- (NSDictionary *)hingeResponseWithArguments:(NSDictionary *)arguments
{
  FBRouteRequest *request = [FBRouteRequest routeRequestWithURL:[NSURL URLWithString:@"http://localhost:8100/"]
                                                  parameters:@{}
                                                   arguments:arguments];
  RouteResponse *response = [RouteResponse new];
  [[FBCustomCommands handleSetSimulatedHingeAngle:request] dispatchWithResponse:response];
  return [NSJSONSerialization JSONObjectWithData:response.responseData options:0 error:nil];
}

- (void)testHingeAngleRejectsInvalidArguments
{
  for (id value in @[@(-1), @181, @YES, @"90", NSNull.null, @(NAN), @(INFINITY)]) {
    NSDictionary *response = [self hingeResponseWithArguments:@{@"angle": value}];
    XCTAssertEqualObjects(response[@"value"][@"error"], @"invalid argument");
  }
  XCTAssertEqualObjects([self hingeResponseWithArguments:@{}][@"value"][@"error"], @"invalid argument");
}

- (void)testHingeAngleRejectsUnsupportedDevices
{
  XCTSkipIf(XCUIDevice.sharedDevice.fb_supportsSimulatedHingeAngle, @"Requires a device without an available hinge");
  for (NSNumber *angle in @[@0, @90, @180]) {
    XCTAssertEqualObjects([self hingeResponseWithArguments:@{@"angle": angle}][@"value"][@"error"],
                          @"unsupported operation");
  }
}

@end

#endif
