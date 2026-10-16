/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBSession.h"
#import "FBSession-Private.h"
#import "FBExceptions.h"
#import "FBConfiguration.h"
#import "XCUIApplicationDouble.h"

@interface FBSession (SystemApplicationTests)
- (BOOL)fb_isApplicationSameAsSystemApp:(XCUIApplication *)application timeout:(NSTimeInterval)timeout;
@end

static id (^FBSystemApplicationLookup)(void);

// Run teardown at the exact point where launch has started but the AUT has
// not yet been published. No wall-clock sleeps or simulator launch timing.
@interface FBAUTLaunchApplicationDouble : XCUIApplicationDouble
@property (nonatomic, copy) void (^duringLaunch)(void);
@property (nonatomic, copy) NSArray *launchArguments;
@property (nonatomic, copy) NSDictionary *launchEnvironment;
@property (nonatomic) BOOL didLaunch;
@end

@implementation FBAUTLaunchApplicationDouble
+ (id)fb_systemApplication
{
  return FBSystemApplicationLookup ? FBSystemApplicationLookup() : nil;
}
- (void)launch
{
  self.didLaunch = YES;
  if (self.duringLaunch) {
    self.duringLaunch();
  }
}
- (BOOL)fb_isSameAppAs:(id)application
{
  return self == application;
}
@end

@interface FBAUTTerminationFailureApplicationDouble : FBAUTLaunchApplicationDouble
@property (nonatomic) BOOL didAttemptTermination;
@end

@implementation FBAUTTerminationFailureApplicationDouble
- (void)terminate
{
  self.didAttemptTermination = YES;
  @throw [NSException exceptionWithName:@"TerminationFailure" reason:nil userInfo:nil];
}
@end

@interface FBAUTLaunchSession : FBSession
@property (nonatomic, strong) FBAUTLaunchApplicationDouble *launchApplication;
@end

@implementation FBAUTLaunchSession
- (XCUIApplication *)makeApplicationWithBundleId:(NSString *)bundleIdentifier
{
  return (id)self.launchApplication;
}
@end

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
  self.shouldTerminateAppValue = FBConfiguration.sharedInstance.shouldTerminateApp;
  FBConfiguration.sharedInstance.shouldTerminateApp = NO;
  self.session = [FBSession initWithApplication:self.testedApplication];
}

- (void)tearDown
{
  if ([self.session isKindOfClass:FBAUTLaunchSession.class]) {
    ((FBAUTLaunchSession *)self.session).launchApplication.duringLaunch = nil;
  }
  FBSystemApplicationLookup = nil;
  [self.session kill];
  FBConfiguration.sharedInstance.shouldTerminateApp = self.shouldTerminateAppValue;
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

- (FBAUTLaunchApplicationDouble *)prepareAUTLaunch
{
  FBAUTLaunchSession *session = [FBAUTLaunchSession new];
  session.identifier = NSUUID.UUID.UUIDString;
  session.launchApplication = [FBAUTLaunchApplicationDouble new];
  [FBSession markSessionActive:session];
  self.session = session;
  return session.launchApplication;
}

- (void)launchAsAUT
{
  [self.session launchApplicationWithBundleId:@"com.facebook.awesome"
                    shouldWaitForQuiescence:nil
                                  arguments:nil
                                environment:nil
                     asApplicationUnderTest:YES];
}

- (void)testCompletedLaunchRegistersAUT
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  XCTAssertNoThrow([self launchAsAUT]);
  XCTAssertEqual([self.session valueForKey:@"testedApplication"], app);
  XCTAssertFalse(app.didTerminate);
}

- (void)testDeletedSessionCleansUpInFlightAUTLaunch
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  FBConfiguration.sharedInstance.shouldTerminateApp = YES;
  FBSession *session = self.session;
  app.duringLaunch = ^{ [session kill]; };
  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException,
                              FBSessionDoesNotExistException);
  XCTAssertTrue(app.didTerminate);
  XCTAssertNil([self.session valueForKey:@"testedApplication"]);
  XCTAssertNil(FBSession.activeSession);
}

- (void)testTerminationFailurePreservesDeletedSessionErrorAndReleasesClaim
{
  [self prepareAUTLaunch];
  FBAUTTerminationFailureApplicationDouble *app = [FBAUTTerminationFailureApplicationDouble new];
  ((FBAUTLaunchSession *)self.session).launchApplication = app;
  FBConfiguration.sharedInstance.shouldTerminateApp = YES;
  FBSession *session = self.session;
  app.duringLaunch = ^{ [session kill]; };

  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException, FBSessionDoesNotExistException);
  XCTAssertTrue(app.didAttemptTermination);
  XCTAssertNil([self.session valueForKey:@"testedApplication"]);
  XCTAssertNil(FBSession.activeSession);

  // Creating the next session must succeed even when cleanup termination throws.
  // A leaked generation claim would make this fail with a session creation error.
  FBSession *replacement = nil;
  XCTAssertNoThrow(replacement = [FBSession initWithApplication:nil]);
  XCTAssertNotNil(replacement);
  XCTAssertEqual(FBSession.activeSession, replacement);
  [replacement kill];
}

- (void)testDeletedSessionPreservesAppWhenTerminationIsDisabled
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  FBSession *session = self.session;
  app.duringLaunch = ^{ [session kill]; };
  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException,
                              FBSessionDoesNotExistException);
  XCTAssertFalse(app.didTerminate);
}

- (void)testAbandonedAUTLaunchDoesNotTerminateReplacementSessionApp
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  FBConfiguration.sharedInstance.shouldTerminateApp = YES;
  FBSession *session = self.session;
  __block FBSession *replacement;
  app.duringLaunch = ^{
    [session kill];
    replacement = [FBSession initWithApplication:(id)app];
  };
  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException,
                              FBSessionDoesNotExistException);
  XCTAssertFalse(app.didTerminate);
  XCTAssertEqual(FBSession.activeSession, replacement);
  [replacement kill];
}

- (void)testAUTLaunchRejectsAnAlreadyDeletedSession
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  [self.session kill];
  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException,
                              FBSessionDoesNotExistException);
  XCTAssertFalse(app.didLaunch);
}

- (void)testSystemApplicationCheckUsesSuppliedApplication
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  FBSystemApplicationLookup = ^id { return app; };
  XCTAssertTrue([self.session fb_isApplicationSameAsSystemApp:(id)app timeout:1.]);
  FBSystemApplicationLookup = ^id { return nil; };
  XCTAssertFalse([self.session fb_isApplicationSameAsSystemApp:(id)app timeout:1.]);
}

- (void)testSystemApplicationLookupExceptionSkipsTermination
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  FBConfiguration.sharedInstance.shouldTerminateApp = YES;
  FBSession *session = self.session;
  app.duringLaunch = ^{ [session kill]; };
  FBSystemApplicationLookup = ^id {
    @throw [NSException exceptionWithName:@"LookupFailure" reason:nil userInfo:nil];
  };
  XCTAssertThrowsSpecificNamed([self launchAsAUT], NSException, FBSessionDoesNotExistException);
  XCTAssertFalse(app.didTerminate);
}

- (void)testSystemApplicationLookupTimeoutSkipsTermination
{
  FBAUTLaunchApplicationDouble *app = [self prepareAUTLaunch];
  dispatch_semaphore_t releaseLookup = dispatch_semaphore_create(0);
  XCTestExpectation *finished = [self expectationWithDescription:@"System application lookup finished"];
  FBSystemApplicationLookup = ^id {
    dispatch_semaphore_wait(releaseLookup, DISPATCH_TIME_FOREVER);
    [finished fulfill];
    return nil;
  };
  @try {
    XCTAssertTrue([self.session fb_isApplicationSameAsSystemApp:(id)app timeout:0.01]);
  } @finally {
    dispatch_semaphore_signal(releaseLookup);
    [self waitForExpectationsWithTimeout:5. handler:nil];
  }
}

@end
