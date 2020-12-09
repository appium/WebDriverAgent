/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

@class FBAlert, XCUIApplication;

NS_ASSUME_NONNULL_BEGIN

@protocol FBAlertsMonitorDelegate

/**
 The callback which is invoked when an unexpected on-screen alert is shown

 @param alert The instance of the current alert
 */
- (void)didDetectAlert:(FBAlert *)alert;

@end

@interface FBAlertsMonitor : NSObject

/*! The delegate which decides on what to do whwn an alert is detected  */
@property (nonatomic, nullable, weak) id<FBAlertsMonitorDelegate> delegate;
/*! The active appication instance. It is updated by the session instance when necessary */
@property (nonatomic, nullable) XCUIApplication *application;

/**
 Creates an instance of alerts monitor.
 The monitoring is done on the main thread and is disabled unless `enable` is called.

 @return Alerts monitor instance
 */
- (instancetype)init;

/**
 Enables alerts monitoring
 */
- (void)enable;

/**
 Disables alerts monitoring
 */
- (void)disable;

@end

NS_ASSUME_NONNULL_END
