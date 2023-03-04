/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBFailureProofTestCase.h"

#import "FBLogger.h"

@implementation FBFailureProofTestCase

- (void)setUp
{
  [super setUp];
  self.continueAfterFailure = YES;
  // https://github.com/appium/appium/issues/13949
  self.shouldSetShouldHaltWhenReceivesControl = NO;
  self.shouldHaltWhenReceivesControl = NO;
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
