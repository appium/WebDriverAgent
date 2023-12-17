/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <WebDriverAgentLib/FBAlert.h>

#import "FBConfiguration.h"
#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "FBMacros.h"

@interface FBAlertTests : FBIntegrationTestCase
@end

@implementation FBAlertTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAlertsPage];
    [FBConfiguration disableApplicationUIInterruptionsHandling];
  });
  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];
  [super tearDown];
}

- (void)showApplicationAlert
{
  [self.testedApplication.buttons[FBShowAlertButtonName] tap];
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count != 0);
}

- (void)showApplicationSheet
{
  [self.testedApplication.buttons[FBShowSheetAlertButtonName] tap];
  FBAssertWaitTillBecomesTrue(self.testedApplication.sheets.count != 0);
}

- (void)testAlertPresence
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertFalse(alert.isPresent);
  [self showApplicationAlert];
  XCTAssertTrue(alert.isPresent);
}

- (void)testAlertText
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);
  [self showApplicationAlert];
  XCTAssertTrue([alert.text containsString:@"Magic"]);
  XCTAssertTrue([alert.text containsString:@"Should read"]);
}

- (void)testAlertLabels
{
  FBAlert* alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.buttonLabels);
  [self showApplicationAlert];
  XCTAssertNotNil(alert.buttonLabels);
  XCTAssertEqual(1, alert.buttonLabels.count);
  XCTAssertEqualObjects(@"Will do", alert.buttonLabels[0]);
}

- (void)testClickAlertButton
{
  FBAlert* alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertFalse([alert clickAlertButton:@"Invalid" error:nil]);
  [self showApplicationAlert];
  XCTAssertFalse([alert clickAlertButton:@"Invalid" error:nil]);
  FBAssertWaitTillBecomesTrue(alert.isPresent);
  XCTAssertTrue([alert clickAlertButton:@"Will do" error:nil]);
  FBAssertWaitTillBecomesTrue(!alert.isPresent);
}

- (void)testAcceptingAlert
{
  NSError *error;
  [self showApplicationAlert];
  XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] acceptWithError:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  XCTAssertNil(error);
}

- (void)testAcceptingAlertWithCustomLocator
{
  NSError *error;
  [self showApplicationAlert];
  [FBConfiguration setAcceptAlertButtonSelector:@"**/XCUIElementTypeButton[-1]"];
  @try {
    XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] acceptWithError:&error]);
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
    XCTAssertNil(error);
  } @finally {
    [FBConfiguration setAcceptAlertButtonSelector:@""];
  }
}

- (void)testDismissingAlert
{
  NSError *error;
  [self showApplicationAlert];
  XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] dismissWithError:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  XCTAssertNil(error);
}

- (void)testDismissingAlertWithCustomLocator
{
  NSError *error;
  [self showApplicationAlert];
  [FBConfiguration setDismissAlertButtonSelector:@"**/XCUIElementTypeButton[-1]"];
  @try {
    XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] dismissWithError:&error]);
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
    XCTAssertNil(error);
  } @finally {
    [FBConfiguration setDismissAlertButtonSelector:@""];
  }
}

- (void)testAlertElement
{
  [self showApplicationAlert];
  XCUIElement *alertElement = [FBAlert alertWithApplication:self.testedApplication].alertElement;
  XCTAssertTrue(alertElement.exists);
  XCTAssertTrue(alertElement.elementType == XCUIElementTypeAlert);
}

- (void)testNotificationAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);
  [self.testedApplication.buttons[@"Create Notification Alert"] tap];
  FBAssertWaitTillBecomesTrue(alert.isPresent);

  XCTAssertTrue([alert.text containsString:@"Would Like to Send You Notifications"]);
  XCTAssertTrue([alert.text containsString:@"Notifications may include"]);
}

// This test case depends on the local app permission state.
- (void)testCameraRollAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);

  [self.testedApplication.buttons[@"Create Camera Roll Alert"] tap];
  FBAssertWaitTillBecomesTrue(alert.isPresent);

  // "Would Like to Access Your Photos" or "Would Like to Access Your Photo Library" displayes on the alert button.
  XCTAssertTrue([alert.text containsString:@"Would Like to Access Your Photo"]);
  // iOS 15 has different UI flow
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
    [[FBAlert alertWithApplication:self.testedApplication] dismissWithError:nil];
    // CI env could take longer time to show up the button, thus it needs to wait a bit.
    XCTAssertTrue([self.testedApplication.buttons[@"Cancel"] waitForExistenceWithTimeout:30.0]);
    [self.testedApplication.buttons[@"Cancel"] tap];
  }
}

- (void)testGPSAccessAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);

  [self.testedApplication.buttons[@"Create GPS access Alert"] tap];
  FBAssertWaitTillBecomesTrue(alert.isPresent);

  XCTAssertTrue([alert.text containsString:@"location"]);
  XCTAssertTrue([alert.text containsString:@"Yo Yo"]);
}

@end
