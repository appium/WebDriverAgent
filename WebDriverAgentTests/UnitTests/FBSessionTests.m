/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBSession.h"
#import "FBConfiguration.h"
#import "XCUIApplicationDouble.h"

@interface FBSessionTests : XCTestCase
@property (nonatomic, strong) FBSession *session;
@property (nonatomic, strong) XCUIApplication *testedApplication;
@property (nonatomic) BOOL shouldTerminateAppValue;
@end

@implementation FBSessionTests

- (void)setUp
{
  [super setUp];
  self.testedApplication = (id)XCUIApplicationDouble.new;
  self.shouldTerminateAppValue = FBConfiguration.shouldTerminateApp;
  [FBConfiguration setShouldTerminateApp:NO];
  self.session = [FBSession initWithApplication:self.testedApplication];
}

- (void)tearDown
{
  [self.session kill];
  [FBConfiguration setShouldTerminateApp:self.shouldTerminateAppValue];
  [super tearDown];
}

- (void)testSessionFetching
{
  FBSession *fetchedSession = [FBSession sessionWithIdentifier:self.session.identifier];
  XCTAssertEqual(self.session, fetchedSession);
}

- (void)testSessionFetchingBadIdentifier
{
  XCTAssertNil([FBSession sessionWithIdentifier:@"FAKE_IDENTIFIER"]);
}

- (void)testSessionCreation
{
  XCTAssertNotNil(self.session.identifier);
  XCTAssertNotNil(self.session.elementCache);
}

- (void)testActiveSession
{
  XCTAssertEqual(self.session, [FBSession activeSession]);
}

- (void)testActiveSessionIsNilAfterKilling
{
  [self.session kill];
  XCTAssertNil([FBSession activeSession]);
}

@end
