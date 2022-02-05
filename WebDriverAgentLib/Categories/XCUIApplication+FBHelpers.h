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
@class XCAccessibilityElement;
@class FBXMLGenerationOptions;

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
 Resets the authorization status for a protected resource. Available since Xcode 11.4

 @param resourceId A valid resource id to reset the auth status for. See https://developer.apple.com/documentation/xctest/xcuiprotectedresource?language=objc
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_resetAuthorizationStatusForResource:(long long)resourceId error:(NSError **)error;

/**
 Return application elements tree in form of nested dictionaries
 */
- (NSDictionary *)fb_tree;

/**
 Return application elements accessibility tree in form of nested dictionaries
 */
- (NSDictionary *)fb_accessibilityTree;

/**
 Return application elements tree in a form of xml string
 with default options.

 @return nil if there was a failure while retriveing the page source.
 */
- (nullable NSString *)fb_xmlRepresentation;

/**
 Return application elements tree in a form of xml string

 @param options Optional values that affect the resulting XML generation process.
 @return nil if there was a failure while retriveing the page source.
 */
- (nullable NSString *)fb_xmlRepresentationWithOptions:(nullable FBXMLGenerationOptions *)options;

/**
 Return application elements tree in form of internal XCTest debugDescription string
 */
- (NSString *)fb_descriptionRepresentation;

/**
 Returns the element, which currently holds the keyboard input focus or nil if there are no such elements.
 */
- (nullable XCUIElement *)fb_activeElement;

#if TARGET_OS_TV
/**
 Returns the element, which currently focused.
 */
- (nullable XCUIElement *)fb_focusedElement;
#endif

/**
 Waits until the current on-screen accessbility element belongs to the current application instance
 @param timeout The maximum time to wait for the element to appear
 @returns Either YES or NO
 */
- (BOOL)fb_waitForAppElement:(NSTimeInterval)timeout;

/**
 Retrieves the information about the applications the given accessiblity elements
 belong to

 @param axElements the list of accessibility elements
 @returns The list of dictionaries. Each dictionary contains `bundleId` and `pid` items
 */
+ (NSArray<NSDictionary<NSString *, id> *> *)fb_appsInfoWithAxElements:(NSArray<XCAccessibilityElement *> *)axElements;

/**
 Retrieves the information about the currently active apps

 @returns The list of dictionaries. Each dictionary contains `bundleId` and `pid` items.
 */
+ (NSArray<NSDictionary<NSString *, id> *> *)fb_activeAppsInfo;

/**
 Tries to dismiss the on-screen keyboard

 @param keyNames Optional list of possible keyboard key labels to tap
 in order to dismiss the keyboard.
 @param error The resulting error object if the method fails to dismiss the keyboard
 @returns YES if the keyboard dismissal was successful or NO otherwise
 */
- (BOOL)fb_dismissKeyboardWithKeyNames:(nullable NSArray<NSString *> *)keyNames
                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
