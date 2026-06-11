/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <objc/message.h>

#import <WebDriverAgentLib/FBFailureProofTestCase.h>
#import <WebDriverAgentLib/XCTestCase.h>

/**
 Regression tests for the machinery that keeps the never-ending server test alive when
 XCTest tries to interrupt it, e.g. after an accessibility snapshot of an unresponsive
 application times out ("app is either unresponsive or taking too long to snapshot").
 */
@interface FBTestInterruptionSuppressionTests : XCTestCase
@end

@implementation FBTestInterruptionSuppressionTests

- (FBFailureProofTestCase *)failureProofTestCase
{
  return [[FBFailureProofTestCase alloc] initWithInvocation:nil];
}

- (void)testHaltFlagCannotBeRaised
{
  FBFailureProofTestCase *testCase = [self failureProofTestCase];
  testCase.shouldHaltWhenReceivesControl = YES;
  XCTAssertFalse(testCase.shouldHaltWhenReceivesControl);
}

- (void)testInterruptionRequestIsSuppressed
{
  FBFailureProofTestCase *testCase = [self failureProofTestCase];
  SEL interruptionSelector = NSSelectorFromString(@"_interruptOrMarkForLaterInterruption");
  XCTAssertTrue([testCase respondsToSelector:interruptionSelector]);
  XCTAssertNoThrow(((void (*)(id, SEL))objc_msgSend)(testCase, interruptionSelector));
  XCTAssertFalse(testCase.shouldHaltWhenReceivesControl);
}

- (void)testIssuesNeverRequestTestInterruption
{
  // Verifies the XCTIssue+FBPatcher swizzle is loaded and applies to mutable subclass
  // instances, which is what XCUIAutomation hands to the test case's issue handler
  XCTIssue *issue = [[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                                compactDescription:@"fake snapshot timeout"];
  XCTMutableIssue *mutableIssue = [issue mutableCopy];
  SEL setShouldInterruptSelector = NSSelectorFromString(@"setShouldInterruptTest:");
  if ([mutableIssue respondsToSelector:setShouldInterruptSelector]) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(mutableIssue, setShouldInterruptSelector, YES);
  }
  SEL shouldInterruptSelector = NSSelectorFromString(@"shouldInterruptTest");
  XCTAssertTrue([mutableIssue respondsToSelector:shouldInterruptSelector]);
  XCTAssertFalse(((BOOL (*)(id, SEL))objc_msgSend)(mutableIssue, shouldInterruptSelector));
}

- (void)testRecordedIssuesAreSwallowed
{
  FBFailureProofTestCase *testCase = [self failureProofTestCase];
  XCTIssue *issue = [[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                                compactDescription:@"fake failure"];
  XCTAssertNoThrow([testCase recordIssue:issue]);
}

@end
