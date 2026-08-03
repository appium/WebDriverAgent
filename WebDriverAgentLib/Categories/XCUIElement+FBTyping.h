/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/FBXCElementSnapshot.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Types a text into the currently focused element.

 @param text text that should be typed
 @param typingSpeed Frequency of typing (letters per sec)
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
BOOL FBTypeText(NSString *text, NSUInteger typingSpeed, NSError **error);

@interface XCUIElement (FBTyping)

/**
 Types a text into element.
 It will try to activate keyboard on element, if element has no keyboard focus.

 @param text text that should be typed
 @param shouldClear Whether to clear the input field before start typing
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_typeText:(NSString *)text
        shouldClear:(BOOL)shouldClear
              error:(NSError **)error;

/**
 Types a text into element.
 It will try to activate keyboard on element, if element has no keyboard focus.

 @param text text that should be typed
 @param shouldClear Whether to clear the input field before start typing
 @param frequency Frequency of typing (letters per sec)
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_typeText:(NSString *)text
        shouldClear:(BOOL)shouldClear
          frequency:(NSUInteger)frequency
              error:(NSError **)error;

/**
 Types a text into element, reusing a snapshot the caller already holds
 instead of fetching a new one. Only pass a snapshot that is known to
 reflect the element's current state (e.g. one taken moments earlier in
 the same operation) - a stale snapshot here will not be detected as such.

 @param text text that should be typed
 @param shouldClear Whether to clear the input field before start typing
 @param frequency Frequency of typing (letters per sec)
 @param snapshot A recent snapshot of the receiver
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_typeText:(NSString *)text
        shouldClear:(BOOL)shouldClear
          frequency:(NSUInteger)frequency
           snapshot:(id<FBXCElementSnapshot>)snapshot
              error:(NSError **)error;

/**
 Clears text on element.
 It will try to activate keyboard on element, if element has no keyboard focus.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_clearTextWithError:(NSError **)error;

/**
 Clears text on element, reusing a snapshot the caller already holds
 instead of fetching a new one. Only pass a snapshot that is known to
 reflect the element's current state (e.g. one taken moments earlier in
 the same operation) - a stale snapshot here will not be detected as such.

 @param snapshot A recent snapshot of the receiver
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_clearTextWithSnapshot:(id<FBXCElementSnapshot>)snapshot
                            error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
