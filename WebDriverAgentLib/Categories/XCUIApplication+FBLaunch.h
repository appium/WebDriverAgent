/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBLaunch)

/**This property must only be used internally */
@property (nonatomic, nullable) NSNumber *fb_didStartWithoutBlockingAlert;

/**
 * Launches the app with background blocking alert validation.
 * This allows to avoid deadlocks or long timeouts on app startup.
 * @param interval The amount of float ssconds between blocking alert presence checks
 * @param exceptionName The name of the exception to be thrown in case an alert is detected
 */
- (void)fb_launchWithInterruptingAlertCheckInterval:(NSTimeInterval)interval
                                      exceptionName:(NSString *)exceptionName;

@end

NS_ASSUME_NONNULL_END
