/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBFailureProofTestCase.h"

#import "FBLogger.h"

@interface XCTestCase (FBIssueHandling)

/**
 Private XCTestCase (XCTIssueHandling category) method called by _handleIssue: when an
 issue carries shouldInterruptTest == YES. Declared here so it can be overridden below.
 */
- (void)_interruptOrMarkForLaterInterruption;

@end

@implementation FBFailureProofTestCase

- (void)setUp
{
  [super setUp];
  self.continueAfterFailure = YES;
  // https://github.com/appium/appium/issues/13949
  self.shouldSetShouldHaltWhenReceivesControl = NO;
  self.shouldHaltWhenReceivesControl = NO;
}

/**
 Automation failures (e.g. accessibility snapshot timeouts on unresponsive applications,
 surfaced through XCUIAutomation's _XCUIFailWithError) bypass recordIssue: completely:
 they are routed through handleIssue: -> _handleIssue:, which records the failure on the
 test case run and then calls this method to interrupt the test. When the never-ending
 server test spins a nested run loop, the default implementation sets
 shouldHaltWhenReceivesControl unconditionally (it does NOT consult
 shouldSetShouldHaltWhenReceivesControl), so the test would be interrupted with
 _XCTestCaseInterruptionException as soon as the nested run loop exits. The server must
 stay alive no matter what, thus the interruption request is suppressed.
 */
- (void)_interruptOrMarkForLaterInterruption
{
  [FBLogger log:@"Suppressing a test interruption request to keep the server alive"];
}

/**
 Never allow the deferred-interruption flag to be raised. XCTest's run loop observer
 calls _interruptTest as soon as this flag is set and the outermost nested run loop
 exits, which would terminate the server.
 */
- (void)setShouldHaltWhenReceivesControl:(BOOL)shouldHaltWhenReceivesControl
{
  if (shouldHaltWhenReceivesControl) {
    [FBLogger log:@"Ignoring an attempt to set shouldHaltWhenReceivesControl to YES"];
    return;
  }
  [super setShouldHaltWhenReceivesControl:shouldHaltWhenReceivesControl];
}

- (void)_recordIssue:(XCTIssue *)issue
{
  NSString *description = [NSString stringWithFormat:@"%@ (%@)", issue.compactDescription, issue.associatedError.description];
  [FBLogger logFmt:@"Issue type: %ld", issue.type];
  [self _enqueueFailureWithDescription:description
                                inFile:issue.sourceCodeContext.location.fileURL.path
                                atLine:issue.sourceCodeContext.location.lineNumber
                              // 5 == XCTIssueTypeUnmatchedExpectedFailure
                              expected:issue.type == 5];
}

- (void)_recordIssue:(XCTIssue *)issue forCaughtError:(id)error
{
  [self _recordIssue:issue];
}

- (void)recordIssue:(XCTIssue *)issue
{
  [self _recordIssue:issue];
}

/**
 Override 'recordFailureWithDescription' to not stop by failures.
 */
- (void)recordFailureWithDescription:(NSString *)description
                              inFile:(NSString *)filePath
                              atLine:(NSUInteger)lineNumber
                            expected:(BOOL)expected
{
  [self _enqueueFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
}

/**
 Private XCTestCase method used to block and tunnel failure messages
 */
- (void)_enqueueFailureWithDescription:(NSString *)description
                                inFile:(NSString *)filePath
                                atLine:(NSUInteger)lineNumber
                              expected:(BOOL)expected
{
  [FBLogger logFmt:@"Enqueue Failure: %@ %@ %lu %d", description, filePath, (unsigned long)lineNumber, expected];
  // TODO: Figure out which error types we want to escalate
}

@end
