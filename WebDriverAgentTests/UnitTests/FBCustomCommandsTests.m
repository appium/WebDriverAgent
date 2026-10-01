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
#import "Doubles/XCUIElementDouble.h"

#if !TARGET_OS_TV && !TARGET_OS_WATCH
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#import "FBResponsePayload.h"
#import "RouteResponse.h"
#endif

#if !TARGET_OS_TV && __clang_major__ >= 15

@interface FBCustomCommands (FBWDATestable)
+ (id<FBResponsePayload>)handleKeyboardInput:(FBRouteRequest *)request;
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

@end

#endif

#if !TARGET_OS_TV && !TARGET_OS_WATCH

@interface FBCustomCommands (FBLocationAuthorizationTestable)
+ (CLLocationManager *)locationAuthorizationManager;
+ (UIApplicationState)locationAuthorizationApplicationState;
+ (id<FBResponsePayload>)handleRequestLocationAuthorization:(FBRouteRequest *)request;
@end

@interface FBLocationAuthorizationManagerDouble : CLLocationManager
@property (nonatomic, assign) CLAuthorizationStatus stubbedStatus;
@property (nonatomic, assign) NSUInteger whenInUseRequests;
@property (nonatomic, assign) NSUInteger alwaysRequests;
@property (nonatomic, assign) NSUInteger locationUpdateRequests;
@end

@implementation FBLocationAuthorizationManagerDouble
- (CLAuthorizationStatus)authorizationStatus
{
  return self.stubbedStatus;
}
- (void)requestWhenInUseAuthorization
{
  self.whenInUseRequests++;
}
- (void)requestAlwaysAuthorization
{
  self.alwaysRequests++;
}
- (void)startUpdatingLocation
{
  self.locationUpdateRequests++;
}
@end

static FBLocationAuthorizationManagerDouble *FBTestLocationManager;
static UIApplicationState FBTestLocationApplicationState;

@interface FBLocationAuthorizationCommandsDouble : FBCustomCommands
@end

@implementation FBLocationAuthorizationCommandsDouble
+ (CLLocationManager *)locationAuthorizationManager
{
  return FBTestLocationManager;
}
+ (UIApplicationState)locationAuthorizationApplicationState
{
  return FBTestLocationApplicationState;
}
@end

@interface FBLocationAuthorizationCommandsTests : XCTestCase
@end

@implementation FBLocationAuthorizationCommandsTests

- (void)setUp
{
  [super setUp];
  FBTestLocationManager = [FBLocationAuthorizationManagerDouble new];
  FBTestLocationManager.stubbedStatus = kCLAuthorizationStatusNotDetermined;
  FBTestLocationApplicationState = UIApplicationStateActive;
}

- (void)tearDown
{
  XCTAssertEqual(FBTestLocationManager.locationUpdateRequests, 0u);
  FBTestLocationManager = nil;
  [super tearDown];
}

- (NSDictionary *)requestAccess:(id)access
{
  FBRouteRequest *request = [FBRouteRequest routeRequestWithURL:
                            [NSURL URLWithString:@"http://localhost:8100/wda/device/location/authorization"]
                                                       parameters:@{}
                                                        arguments:access ? @{@"access": access} : @{}];
  id<FBResponsePayload> payload = [FBLocationAuthorizationCommandsDouble handleRequestLocationAuthorization:request];
  RouteResponse *response = [RouteResponse new];
  [payload dispatchWithResponse:response];
  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response.responseData options:0 error:nil];
  return json[@"value"];
}

- (void)testRequestsWhenInUseWithoutWaitingForUserInteraction
{
  XCTAssertEqualObjects([self requestAccess:@"whenInUse"][@"authorizationStatus"], @0);
  XCTAssertEqual(FBTestLocationManager.whenInUseRequests, 1u);
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 0u);
}

- (void)testRequestsAlwaysFromUndetermined
{
  XCTAssertEqualObjects([self requestAccess:@"always"][@"authorizationStatus"], @0);
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 1u);
  XCTAssertEqual(FBTestLocationManager.whenInUseRequests, 0u);
}

- (void)testUpgradesWhenInUseToAlways
{
  FBTestLocationManager.stubbedStatus = kCLAuthorizationStatusAuthorizedWhenInUse;
  XCTAssertEqualObjects([self requestAccess:@"always"][@"authorizationStatus"], @4);
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 1u);
}

- (void)testRejectsRequestsThatNeedAPromptWhileNotActive
{
  for (NSNumber *state in @[@(UIApplicationStateBackground), @(UIApplicationStateInactive)]) {
    FBTestLocationApplicationState = state.integerValue;
    for (NSString *access in @[@"whenInUse", @"always"]) {
      XCTAssertEqualObjects([self requestAccess:access][@"error"], @"invalid element state");
    }
    FBTestLocationManager.stubbedStatus = kCLAuthorizationStatusAuthorizedWhenInUse;
    XCTAssertEqualObjects([self requestAccess:@"always"][@"error"], @"invalid element state");
    FBTestLocationManager.stubbedStatus = kCLAuthorizationStatusNotDetermined;
  }
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 0u);
  XCTAssertEqual(FBTestLocationManager.whenInUseRequests, 0u);
}

- (void)testReturnsDecidedStatusesWithoutPrompting
{
  FBTestLocationApplicationState = UIApplicationStateBackground;
  for (NSNumber *status in @[@(kCLAuthorizationStatusDenied), @(kCLAuthorizationStatusRestricted),
                            @(kCLAuthorizationStatusAuthorizedAlways)]) {
    FBTestLocationManager.stubbedStatus = status.intValue;
    for (NSString *access in @[@"whenInUse", @"always"]) {
      XCTAssertEqualObjects([self requestAccess:access][@"authorizationStatus"], status);
    }
  }
  FBTestLocationManager.stubbedStatus = kCLAuthorizationStatusAuthorizedWhenInUse;
  XCTAssertEqualObjects([self requestAccess:@"whenInUse"][@"authorizationStatus"], @4);
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 0u);
  XCTAssertEqual(FBTestLocationManager.whenInUseRequests, 0u);
}

- (void)testRejectsMissingAndInvalidAccess
{
  XCTAssertEqualObjects([self requestAccess:nil][@"error"], @"invalid argument");
  for (id access in @[@"Always", @"", @3, NSNull.null, @[], @{}]) {
    XCTAssertEqualObjects([self requestAccess:access][@"error"], @"invalid argument");
  }
  XCTAssertEqual(FBTestLocationManager.alwaysRequests, 0u);
  XCTAssertEqual(FBTestLocationManager.whenInUseRequests, 0u);
}

- (void)testAuthorizationManagerSurvivesBetweenRequests
{
  __weak CLLocationManager *manager;
  @autoreleasepool {
    manager = [FBCustomCommands locationAuthorizationManager];
  }
  XCTAssertNotNil(manager);
  XCTAssertEqual(manager, [FBCustomCommands locationAuthorizationManager]);
}

@end

#endif
