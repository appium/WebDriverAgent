/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <WebDriverAgentLib/FBalert.h>
#import <WebDriverAgentLib/FBDebugLogDelegateDecorator.h>
#import <WebDriverAgentLib/FBConfiguration.h>
#import <WebDriverAgentLib/FBFailureProofTestCase.h>
#import <WebDriverAgentLib/FBWebServer.h>
#import <WebDriverAgentLib/XCTestCase.h>

@interface UITestingUITests : FBFailureProofTestCase <FBWebServerDelegate>
@property (nonatomic) id<NSObject> interruptionMonitorToken;
@end

@implementation UITestingUITests

+ (void)setUp
{
  [FBDebugLogDelegateDecorator decorateXCTestLogger];
  [FBConfiguration disableRemoteQueryEvaluation];
  [super setUp];
}

- (void)setUp
{
  [super setUp];
  self.interruptionMonitorToken = [self addUIInterruptionMonitorWithDescription:@"WebDriverAgent Alerts Handler" handler:^BOOL(XCUIElement * _Nonnull interruptingElement) {
    FBAlert *alert = [FBAlert alertWithElement:interruptingElement];
    NSError *error;
    if ([FBConfiguration.autoAlertAction isEqualToString:FB_ALERT_ACCEPT_ACTION]) {
      [alert acceptWithError:&error];
    }
    if ([FBConfiguration.autoAlertAction isEqualToString:FB_ALERT_DISMISS_ACTION]) {
      [alert dismissWithError:&error];
    }

    return YES;
  }];
}

- (void)tearDown
{
  [self removeUIInterruptionMonitor:self.interruptionMonitorToken];
  [super tearDown];
}

/**
 Never ending test used to start WebDriverAgent
 */
- (void)testRunner
{
  FBWebServer *webServer = [[FBWebServer alloc] init];
  webServer.delegate = self;
  [webServer startServing];
}

#pragma mark - FBWebServerDelegate

- (void)webServerDidRequestShutdown:(FBWebServer *)webServer
{
  [webServer stopServing];
}

@end
