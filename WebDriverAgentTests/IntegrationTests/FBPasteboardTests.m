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
#import "XCUIElement+FBTyping.h"
#import "FBPasteboard.h"
#import "FBTestMacros.h"
#import "FBXCodeCompatibility.h"

@interface FBPasteboardTests : FBIntegrationTestCase
@end

@implementation FBPasteboardTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  [self goToAttributesPage];
}

- (void)testSetPasteboard
{
  NSString *text = @"Happy pasting";
  XCUIElement *textField = self.testedApplication.textFields[@"aIdentifier"];
  NSError *error;
  BOOL result = [FBPasteboard setData:(NSData *)[text dataUsingEncoding:NSUTF8StringEncoding]
                              forType:@"plaintext"
                                error:&error];
  XCTAssertTrue(result);
  XCTAssertNil(error);
  [textField tap];
  XCTAssertTrue([textField fb_clearTextWithError:&error]);
  [textField pressForDuration:2.0];
  XCUIElementQuery *pastItemsQuery = [[self.testedApplication descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"Paste"];
  if (![pastItemsQuery.firstMatch waitForExistenceWithTimeout:2.0]) {
    XCTFail(@"No matched element named 'Paste'");
  }
  XCUIElement *pasteItem = pastItemsQuery.fb_firstMatch;
  XCTAssertNotNil(pasteItem);
  [pasteItem tap];
  FBAssertWaitTillBecomesTrue([textField.value isEqualToString:text]);
}

- (void)testGetPasteboard
{
  NSString *text = @"Happy copying";
  XCUIElement *textField = self.testedApplication.textFields[@"aIdentifier"];
  NSError *error;
  XCTAssertTrue([textField fb_typeText:text shouldClear:NO error:&error]);
  [textField pressForDuration:2.0];
  XCUIElement *selectAllItem = [[self.testedApplication descendantsMatchingType:XCUIElementTypeAny]
                                matchingIdentifier:@"Select All"].firstMatch;
  XCTAssertTrue([selectAllItem waitForExistenceWithTimeout:5]);
  [selectAllItem tap];
  [textField pressForDuration:2.0];
  XCUIElement *copyItem = [[self.testedApplication descendantsMatchingType:XCUIElementTypeAny]
                           matchingIdentifier:@"Copy"].firstMatch;
  XCTAssertTrue([copyItem waitForExistenceWithTimeout:5]);
  [copyItem tap];
  FBWaitExact(1.0);
  NSData *result = [FBPasteboard dataForType:@"plaintext" error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(textField.value, [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding]);
}

- (void)testUrlCopyPaste
{
  NSString *urlString = @"http://appium.io?some=value";
  NSError *error;
  XCTAssertTrue([FBPasteboard setData:(NSData *)[urlString dataUsingEncoding:NSUTF8StringEncoding]
                              forType:@"url"
                              error:&error]);
  XCTAssertNil(error);
  NSData *result = [FBPasteboard dataForType:@"url" error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(urlString, [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding]);
}

@end


