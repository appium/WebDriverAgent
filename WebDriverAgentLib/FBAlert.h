/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class XCUIApplication;
@class XCUIElement;

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
 Creates alert helper for given application

 @param element The element which represents the alert
 */
+ (instancetype)alertWithElement:(XCUIElement *)element;

/**
 Determines whether alert is present
 */
- (BOOL)isPresent;

/**
 Gets the labels of the buttons visible in the alert
 */
- (nullable NSArray *)buttonLabels;

/**
 Returns alert's title and description separated by new lines
 */
- (nullable NSString *)text;

/**
 Accepts alert, if present

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)acceptWithError:(NSError **)error;

/**
 Dismisses alert, if present

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)dismissWithError:(NSError **)error;

/**
 Clicks on an alert button, if present
 
 @param label The label of the button on which to click.
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation suceeds, otherwise NO.
 */
- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error;

/**
 XCUElement that represents alert
 */
- (nullable XCUIElement *)alertElement;

/**
 Types a text into an input inside the alert container, if it is present

 @param text the text to type
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)typeText:(NSString *)text error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
