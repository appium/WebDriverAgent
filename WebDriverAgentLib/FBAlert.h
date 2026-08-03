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

 An FBAlert instance resolves the alert (and, if found, its snapshot) at
 most once, lazily, on the first call to isPresent, text, buttonLabels,
 accept, dismiss, clickAlertButton:, clickElementMatchingClassChain:, or
 typeText: - every subsequent call on the same instance reuses that result
 rather than re-querying the live UI. This makes an isPresent check
 immediately followed by an action (e.g. the auto-accept flow) act on the
 exact same alert it just observed. Create a fresh FBAlert instance (via
 alertWithApplication:) to observe the current UI state again.
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

 @throws FBAlertNotPresentException if no alert is present.
 @throws FBAlertActionFailedException if the accept button could not be found.
 */
- (void)accept;

/**
 Dismisses alert, if present.
 See isPresent for how presence is resolved.

 @throws FBAlertNotPresentException if no alert is present.
 @throws FBAlertActionFailedException if the dismiss button could not be found.
 */
- (void)dismiss;

/**
 Clicks on an alert button, if present.
 See isPresent for how presence is resolved.

 @param label The label of the button on which to click.
 @throws FBAlertNotPresentException if no alert is present.
 @throws FBAlertActionFailedException if no button with the given label could be found.
 */
- (void)clickAlertButton:(NSString *)label;

/**
 Taps the first descendant of the alert matching the given class chain
 selector, if present.
 See isPresent for how presence is resolved.

 @param classChain The class chain selector to match against the alert's descendants.
 @throws FBAlertNotPresentException if no alert is present.
 @throws FBAlertActionFailedException if no matching element could be found.
 */
- (void)clickElementMatchingClassChain:(NSString *)classChain;

/**
 Types a text into an input inside the alert container, if it is present.
 See isPresent for how presence is resolved.

 @param text the text to type
 @throws FBAlertNotPresentException if no alert is present.
 @throws FBAlertSetTextFailedException if there is no single input field to type into, or typing itself fails.
 */
- (void)typeText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
