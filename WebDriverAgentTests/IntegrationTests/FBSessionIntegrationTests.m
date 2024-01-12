/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBExceptions.h"
#import "FBMacros.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "FBTestMacros.h"
#import "FBUnattachedAppLauncher.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication.h"

@interface FBSession (Tests)

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

- (void)testLaunchUnattachedApp
{
  [FBUnattachedAppLauncher launchAppWithBundleId:SETTINGS_BUNDLE_ID];
  [self.session kill];
  XCTAssertEqualObjects(SETTINGS_BUNDLE_ID, XCUIApplication.fb_activeApplication.bundleID);
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
