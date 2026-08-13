/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <WebDriverAgentLib/FBAlert.h>
#import <XCTest/XCTest.h>

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
  [self resetPermissions];
  [self launchApplication];
  [self goToAlertsPage];
  [FBConfiguration.sharedInstance disableApplicationUIInterruptionsHandling];
}

- (void)resetPermissions
{
  if (@available(iOS 13.4, *)) {
    NSArray* resources = @[
      @(XCUIProtectedResourceContacts),
      @(XCUIProtectedResourceCalendar),
      @(XCUIProtectedResourceReminders),
      @(XCUIProtectedResourcePhotos),
      @(XCUIProtectedResourceMicrophone),
      @(XCUIProtectedResourceCamera),
      @(XCUIProtectedResourceMediaLibrary),
      @(XCUIProtectedResourceLocation),
    ];
    for (NSNumber *resource in resources) {
      [self.testedApplication resetAuthorizationStatusForResource:(XCUIProtectedResource)[resource unsignedLongValue]];
    }
  }
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
  XCTAssertFalse([FBAlert alertWithApplication:self.testedApplication].isPresent);
  [self showApplicationAlert];
  XCTAssertTrue([FBAlert alertWithApplication:self.testedApplication].isPresent);
}

- (void)testAlertText
{
  XCTAssertNil([FBAlert alertWithApplication:self.testedApplication].text);
  [self showApplicationAlert];
  NSString *text = [FBAlert alertWithApplication:self.testedApplication].text;
  XCTAssertTrue([text containsString:@"Magic"]);
  XCTAssertTrue([text containsString:@"Should read"]);
}

- (void)testAlertLabels
{
  XCTAssertNil([FBAlert alertWithApplication:self.testedApplication].buttonLabels);
  [self showApplicationAlert];
  NSArray *labels = [FBAlert alertWithApplication:self.testedApplication].buttonLabels;
  XCTAssertNotNil(labels);
  XCTAssertEqual(1, labels.count);
  XCTAssertEqualObjects(@"Will do", labels[0]);
}

- (void)testClickAlertButton
{
  XCTAssertThrows([[FBAlert alertWithApplication:self.testedApplication] clickAlertButton:@"Invalid"]);
  [self showApplicationAlert];
  XCTAssertThrows([[FBAlert alertWithApplication:self.testedApplication] clickAlertButton:@"Invalid"]);
  FBAssertWaitTillBecomesTrue([FBAlert alertWithApplication:self.testedApplication].isPresent);
  XCTAssertNoThrow([[FBAlert alertWithApplication:self.testedApplication] clickAlertButton:@"Will do"]);
  FBAssertWaitTillBecomesTrue(![FBAlert alertWithApplication:self.testedApplication].isPresent);
}

- (void)testAcceptingAlert
{
  [self showApplicationAlert];
  XCTAssertNoThrow([[FBAlert alertWithApplication:self.testedApplication] accept]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
}

- (void)testAcceptingAlertWithCustomLocator
{
  [self showApplicationAlert];
  FBConfiguration.sharedInstance.acceptAlertButtonSelector = @"**/XCUIElementTypeButton[-1]";
  @try {
    XCTAssertNoThrow([[FBAlert alertWithApplication:self.testedApplication] accept]);
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  } @finally {
    FBConfiguration.sharedInstance.acceptAlertButtonSelector = @"";
  }
}

- (void)testDismissingAlert
{
  [self showApplicationAlert];
  XCTAssertNoThrow([[FBAlert alertWithApplication:self.testedApplication] dismiss]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
}

- (void)testDismissingAlertWithCustomLocator
{
  [self showApplicationAlert];
  FBConfiguration.sharedInstance.dismissAlertButtonSelector = @"**/XCUIElementTypeButton[-1]";
  @try {
    XCTAssertNoThrow([[FBAlert alertWithApplication:self.testedApplication] dismiss]);
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  } @finally {
    FBConfiguration.sharedInstance.dismissAlertButtonSelector = @"";
  }
}

- (void)testNotificationAlert
{
  XCTAssertNil([FBAlert alertWithApplication:self.testedApplication].text);
  [self.testedApplication.buttons[@"Create Notification Alert"] tap];
  FBAssertWaitTillBecomesTrue([FBAlert alertWithApplication:self.testedApplication].isPresent);

  NSString *text = [FBAlert alertWithApplication:self.testedApplication].text;
  XCTAssertTrue([text containsString:@"Would Like to Send You Notifications"]);
  XCTAssertTrue([text containsString:@"Notifications may include"]);
}

- (void)testCameraRollAlert
{
  XCTAssertNil([FBAlert alertWithApplication:self.testedApplication].text);

  [self.testedApplication.buttons[@"Create Camera Roll Alert"] tap];
  FBAssertWaitTillBecomesTrue([FBAlert alertWithApplication:self.testedApplication].isPresent);
}

- (void)testGPSAccessAlert
{
  XCTAssertNil([FBAlert alertWithApplication:self.testedApplication].text);

  [self.testedApplication.buttons[@"Create GPS access Alert"] tap];
  FBAssertWaitTillBecomesTrue([FBAlert alertWithApplication:self.testedApplication].isPresent);

  NSString *text = [FBAlert alertWithApplication:self.testedApplication].text;
  XCTAssertTrue([text containsString:@"location"]);
  XCTAssertTrue([text containsString:@"Yo Yo"]);
}

@end
