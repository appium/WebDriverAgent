/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBCapabilities.h"
#import "FBExceptions.h"
#import "FBMacros.h"
#import "FBResponsePayload.h"
#import "FBSession.h"
#import "FBSessionCommands.h"
#import "FBXCodeCompatibility.h"
#import "FBTestMacros.h"
#import "FBUnattachedAppLauncher.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIApplication.h"

@interface FBSession (Tests)

@end

@interface FBSessionCommands (FBWDATestable)
+ (nullable id<FBResponsePayload>)prepareApplicationForSessionWithBundleID:(nullable NSString *)bundleID
                                                                initialUrl:(nullable NSString *)initialUrl
                                                            capabilities:(NSDictionary<NSString *, id> *)capabilities
                                                             application:(XCUIApplication *_Nullable *_Nonnull)applicationOut;
@end

@interface FBSessionIntegrationTests : FBIntegrationTestCase
@property (nonatomic) FBSession *session;
@end


static NSString *const SETTINGS_BUNDLE_ID = @"com.apple.Preferences";

@implementation FBSessionIntegrationTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:self.testedApplication.bundleID];
  self.session = [FBSession initWithApplication:app];
}

- (void)tearDown
{
  [self.session kill];
  [super tearDown];
}

- (void)testSettingsAppCanBeOpenedInScopeOfTheCurrentSession
{
  XCUIApplication *testedApp = XCUIApplication.fb_activeApplication;
  [self.session launchApplicationWithBundleId:SETTINGS_BUNDLE_ID
                      shouldWaitForQuiescence:nil
                                    arguments:nil
                                  environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:SETTINGS_BUNDLE_ID]);
  XCTAssertEqual([self.session applicationStateWithBundleId:SETTINGS_BUNDLE_ID], 4);
  [self.session activateApplicationWithBundleId:testedApp.bundleID];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString: testedApp.bundleID]);
  XCTAssertEqual([self.session applicationStateWithBundleId:testedApp.bundleID], 4);
}

- (void)testSettingsAppCanBeReopenedInScopeOfTheCurrentSession
{
  XCUIApplication *systemApp = self.springboard;
  [self.session launchApplicationWithBundleId:SETTINGS_BUNDLE_ID
                      shouldWaitForQuiescence:nil
                                    arguments:nil
                                  environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:SETTINGS_BUNDLE_ID]);
  XCTAssertTrue([self.session terminateApplicationWithBundleId:SETTINGS_BUNDLE_ID]);
  FBAssertWaitTillBecomesTrue([systemApp.bundleID isEqualToString:self.session.activeApplication.bundleID]);
  [self.session launchApplicationWithBundleId:SETTINGS_BUNDLE_ID
                      shouldWaitForQuiescence:nil
                                    arguments:nil
                                  environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:SETTINGS_BUNDLE_ID]);
}

- (void)testMainAppCanBeReactivatedInScopeOfTheCurrentSession
{
  XCUIApplication *testedApp = XCUIApplication.fb_activeApplication;
  [self.session launchApplicationWithBundleId:SETTINGS_BUNDLE_ID
                      shouldWaitForQuiescence:nil
                                    arguments:nil
                                  environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:SETTINGS_BUNDLE_ID]);
  [self.session activateApplicationWithBundleId:testedApp.bundleID];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:testedApp.bundleID]);
}

- (void)testMainAppCanBeRestartedInScopeOfTheCurrentSession
{
  XCUIApplication *systemApp = self.springboard;
  XCUIApplication *testedApp = [[XCUIApplication alloc] initWithBundleIdentifier:self.testedApplication.bundleID];
  [self.session terminateApplicationWithBundleId:testedApp.bundleID];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:systemApp.bundleID]);
  [self.session launchApplicationWithBundleId:testedApp.bundleID
                      shouldWaitForQuiescence:nil
                                    arguments:nil
                                  environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:testedApp.bundleID]);
}

- (XCUIApplication *)prepareApplicationUnderTestWithoutLaunchingWithCapabilities:(NSDictionary<NSString *, id> *)capabilities
{
  NSString *bundleId = (NSString *)self.testedApplication.bundleID;
  [self.testedApplication terminate];
  FBAssertWaitTillBecomesTrue(self.testedApplication.state == XCUIApplicationStateNotRunning);
  [self.session kill];

  XCUIApplication *app = nil;
  id<FBResponsePayload> errorResponse = [FBSessionCommands prepareApplicationForSessionWithBundleID:bundleId
                                                                                        initialUrl:nil
                                                                                      capabilities:capabilities
                                                                                       application:&app];
  XCTAssertNil(errorResponse);
  XCTAssertNotNil(app);
  XCTAssertEqualObjects(bundleId, app.bundleID);
  XCTAssertEqual(XCUIApplicationStateNotRunning, app.state);

  self.session = [FBSession initWithApplication:app];
  return app;
}

- (void)testApplicationUnderTestCanBeSetWithoutBeingLaunched
{
  XCUIApplication *app = [self prepareApplicationUnderTestWithoutLaunchingWithCapabilities:@{
    FB_CAP_SHOULD_LAUNCH_APP: @NO,
  }];
  XCTAssertNotEqualObjects(app.bundleID, self.session.activeApplication.bundleID);

  XCUIApplication *launchedApp = [self.session launchApplicationWithBundleId:(NSString *)app.bundleID
                                                     shouldWaitForQuiescence:nil
                                                                   arguments:nil
                                                                 environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:(NSString *)app.bundleID]);
  XCTAssertEqual(app, launchedApp);
  XCTAssertEqual(app, self.session.activeApplication);
  XCTAssertTrue(launchedApp.fb_shouldWaitForQuiescence);
}

- (void)testApplicationUnderTestSetWithoutBeingLaunchedRespectsQuiescenceCapability
{
  XCUIApplication *app = [self prepareApplicationUnderTestWithoutLaunchingWithCapabilities:@{
    FB_CAP_SHOULD_LAUNCH_APP: @NO,
    FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE: @NO,
  }];

  XCUIApplication *launchedApp = [self.session launchApplicationWithBundleId:(NSString *)app.bundleID
                                                     shouldWaitForQuiescence:nil
                                                                   arguments:nil
                                                                 environment:nil];
  FBAssertWaitTillBecomesTrue([self.session.activeApplication.bundleID isEqualToString:(NSString *)app.bundleID]);
  XCTAssertEqual(app, launchedApp);
  XCTAssertFalse(launchedApp.fb_shouldWaitForQuiescence);
}

- (void)testLaunchUnattachedApp
{
  [FBUnattachedAppLauncher launchAppWithBundleId:SETTINGS_BUNDLE_ID];
}

- (void)testAppWithInvalidBundleIDCannotBeStarted
{
  XCUIApplication *testedApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"yolo"];
  @try {
    [testedApp launch];
    XCTFail(@"An exception is expected to be thrown");
  } @catch (NSException *exception) {
    XCTAssertEqualObjects(FBApplicationMissingException, exception.name);
  }
}

- (void)testAppWithInvalidBundleIDCannotBeActivated
{
  XCUIApplication *testedApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"yolo"];
  @try {
    [testedApp activate];
    XCTFail(@"An exception is expected to be thrown");
  } @catch (NSException *exception) {
    XCTAssertEqualObjects(FBApplicationMissingException, exception.name);
  }
}

@end
