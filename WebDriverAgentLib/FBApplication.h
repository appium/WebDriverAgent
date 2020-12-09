/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/XCUIApplication.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBApplication : XCUIApplication

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
 Constructor used to get the system application
 */
+ (instancetype)fb_systemApplication;

/**
 Retrieves the list of all currently active applications
 */
+ (NSArray<FBApplication *> *)fb_activeApplications;

@end

NS_ASSUME_NONNULL_END
