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
#import "FBApplication.h"
#import "FBMacros.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "FBTestMacros.h"
#import "XCUIElement+FBUtilities.h"


@interface FBAutoAlertsHandlerTests : FBIntegrationTestCase
@property (nonatomic) FBSession *session;
@end


@implementation FBAutoAlertsHandlerTests

- (void)setUp
{
  [super setUp];

  [self launchApplication];
  [self goToAlertsPage];

  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];

  if (self.session) {
    [self.session kill];
  }

  [super tearDown];
}

// The test is flaky on slow Travis CI
- (void)disabled_testAutoAcceptingOfAlerts
{
  if (SYSTEM_VERSION_LESS_THAN(@"11.0")) {
    return;
  }
  
  self.session = [FBSession
                  initWithApplication:FBApplication.fb_activeApplication
                  defaultAlertAction:@"accept"];
  for (int i = 0; i < 2; i++) {
    [self.testedApplication.buttons[FBShowAlertButtonName] fb_tapWithError:nil];
    [self.testedApplication fb_waitUntilStable];
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  }
}

// The test is flaky on slow Travis CI
- (void)disabled_testAutoDismissingOfAlerts
{
  if (SYSTEM_VERSION_LESS_THAN(@"11.0")) {
    return;
  }

  self.session = [FBSession
                  initWithApplication:FBApplication.fb_activeApplication
                  defaultAlertAction:@"dismiss"];
  for (int i = 0; i < 2; i++) {
    [self.testedApplication.buttons[FBShowAlertButtonName] fb_tapWithError:nil];
    [self.testedApplication fb_waitUntilStable];
    FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  }
}

@end
