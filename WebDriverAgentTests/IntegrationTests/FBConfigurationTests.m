/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree.
*/

#import <XCTest/XCTest.h>
#import "FBIntegrationTestCase.h"

#import "FBConfiguration.h"
#import "FBRuntimeUtils.h"
#import "FBTestMacros.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"

@interface FBConfigurationTests : FBIntegrationTestCase

@end

@implementation FBConfigurationTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)testReduceMotion
{
  BOOL defaultReduceMotionEnabled = FBConfiguration.sharedInstance.reduceMotionEnabled;

  FBConfiguration.sharedInstance.reduceMotionEnabled = YES;
  XCTAssertTrue(FBConfiguration.sharedInstance.reduceMotionEnabled);

  FBConfiguration.sharedInstance.reduceMotionEnabled = defaultReduceMotionEnabled;
  XCTAssertEqual(FBConfiguration.sharedInstance.reduceMotionEnabled, defaultReduceMotionEnabled);
}

- (void)testAccessibilityDeadlineAbortsSnapshotRequestForDeadlockedApp
{
  if (FBIntegrationTestCase.isRunningInCI) {
    XCTSkip(@"Deliberately freezes the app for several seconds, too slow/flaky for CI");
  }

  NSTimeInterval previousDeadline = FBConfiguration.sharedInstance.accessibilityDeadline;
  // Also bounds any snapshot-based wait -tap itself may perform once the app is stuck.
  FBConfiguration.sharedInstance.accessibilityDeadline = 3.0;
  @try {
    XCUIElement *deadlockButton = self.testedApplication.buttons[@"Deadlock app"];
    FBAssertWaitTillBecomesTrue(deadlockButton.fb_isVisible);
    // Freezes the app's main thread for 20s - see -[ViewController deadlockApp:].
    [deadlockButton tap];

    NSError *error;
    NSDate *start = [NSDate date];
    id snapshot = [self.testedApplication snapshotWithError:&error];
    NSTimeInterval elapsed = -start.timeIntervalSinceNow;

    XCTAssertNil(snapshot);
    XCTAssertNotNil(error);
    // Should abort close to accessibilityDeadline (plus XCTest's own internal
    // retries), not hang indefinitely waiting for the frozen app (#1210).
    XCTAssertLessThan(elapsed, 20.0);
  } @finally {
    FBConfiguration.sharedInstance.accessibilityDeadline = previousDeadline;
    [self.testedApplication terminate];
  }
}

@end
