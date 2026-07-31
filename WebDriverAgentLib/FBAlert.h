/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@class XCUIApplication;

NS_ASSUME_NONNULL_BEGIN

/**
 Alert helper class that abstracts alert handling
 */
@interface FBAlert : NSObject

/**
 Creates alert helper for given application

 @param application The application that contains the alert
 */
+ (instancetype)alertWithApplication:(XCUIApplication *)application;

/**
 Determines whether alert is present.

 Not cached: this, text, buttonLabels, acceptWithError:, dismissWithError:,
 clickAlertButton:error:, clickElementMatchingClassChain:error:, and
 typeText:error: each independently re-resolve the alert against the live
 UI on every call. Calling isPresent before one of the others therefore
 pays for two resolutions - prefer calling the action directly and handling
 its own "not present" error, unless you specifically need to check
 presence without acting on it.
 */
- (BOOL)isPresent;

/**
 Gets the labels of the buttons visible in the alert.
 See isPresent for how presence is resolved.
 */
- (nullable NSArray *)buttonLabels;

/**
 Returns alert's title and description separated by new lines.
 See isPresent for how presence is resolved.
 */
- (nullable NSString *)text;

/**
 Accepts alert, if present.
 See isPresent for how presence is resolved.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)acceptWithError:(NSError **)error;

/**
 Dismisses alert, if present.
 See isPresent for how presence is resolved.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)dismissWithError:(NSError **)error;

/**
 Clicks on an alert button, if present.
 See isPresent for how presence is resolved.

 @param label The label of the button on which to click.
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation suceeds, otherwise NO.
 */
- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error;

/**
 Taps the first descendant of the alert matching the given class chain
 selector, if present.
 See isPresent for how presence is resolved.

 @param classChain The class chain selector to match against the alert's descendants.
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)clickElementMatchingClassChain:(NSString *)classChain error:(NSError **)error;

/**
 Types a text into an input inside the alert container, if it is present.
 See isPresent for how presence is resolved.

 @param text the text to type
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)typeText:(NSString *)text error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
