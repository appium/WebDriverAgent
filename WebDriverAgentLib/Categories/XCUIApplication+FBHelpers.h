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
@protocol FBXCAccessibilityElement;
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
+ (NSArray<NSDictionary<NSString *, id> *> *)fb_appsInfoWithAxElements:(NSArray<id<FBXCAccessibilityElement>> *)axElements;

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

/**
 A wrapper over https://developer.apple.com/documentation/xctest/xcuiapplication/4190847-performaccessibilityauditwithaud?language=objc

 @param auditTypes Combination of https://developer.apple.com/documentation/xctest/xcuiaccessibilityaudittype?language=objc
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return List of found issues or nil if there was a failure
 */
- (nullable NSArray<NSDictionary<NSString *, NSString*> *> *)fb_performAccessibilityAuditWithAuditTypesSet:(NSSet<NSString *> *)auditTypes
                                                                                                     error:(NSError **)error;

/**
 A wrapper over https://developer.apple.com/documentation/xctest/xcuiapplication/4190847-performaccessibilityauditwithaud?language=objc

 @param auditTypes Combination of https://developer.apple.com/documentation/xctest/xcuiaccessibilityaudittype?language=objc
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return List of found issues or nil if there was a failure
 */
- (nullable NSArray<NSDictionary<NSString *, NSString*> *> *)fb_performAccessibilityAuditWithAuditTypes:(uint64_t)auditTypes
                                                                                                  error:(NSError **)error;
/**
 Constructor used to get current active application
 */
+ (instancetype)fb_activeApplication;

/**
 Constructor used to get current active application

 @param bundleId The bundle identifier of an app, which should be selected as active by default
 if it is present in the list of active applications
 */
+ (instancetype)fb_activeApplicationWithDefaultBundleId:(nullable NSString *)bundleId;

/**
 Constructor used to get the system application (e.g. Springboard on iOS)
 */
+ (instancetype)fb_systemApplication;

/**
 Retrieves the list of all currently active applications
 */
+ (NSArray<XCUIApplication *> *)fb_activeApplications;

/**
 Switch to system app (called Springboard on iOS)

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
+ (BOOL)fb_switchToSystemApplicationWithError:(NSError **)error;

/**
 Determines whether the other app is the same as the current one

 @param otherApp  Other app instance
 @return YES if the other app has the same identifier
 */
- (BOOL)fb_isSameAppAs:(nullable XCUIApplication *)otherApp;

@end

NS_ASSUME_NONNULL_END
