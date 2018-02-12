/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

@class XCElementSnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBHelpers)

/**
 Deactivates application for given time

 @param duration amount of time application should deactivated
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_deactivateWithDuration:(NSTimeInterval)duration error:(NSError **)error;

/**
 Return application elements tree in form of nested dictionaries
 */
- (NSDictionary *)fb_tree;

/**
 Return application elements accessibility tree in form of nested dictionaries
 */
- (NSDictionary *)fb_accessibilityTree;

/**
 Return application elements tree in form of xml string
 */
- (nullable NSString *)fb_xmlRepresentation;

/**
 Return application elements tree in form of internal XCTest debugDescription string
 */
- (NSString *)fb_descriptionRepresentation;

/**
 Opens the particular url scheme using Siri voice recognition helpers.
 This will only work since XCode 8.3/iOS 10.3
 
 @param url The url scheme represented as a string, for example https://apple.com
 @return YES if the operation was successful
 */
- (BOOL)fb_openUrl:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
