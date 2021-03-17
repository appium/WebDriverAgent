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

@interface FBNotificationsHelper : NSObject

/**
 Creates an expectation that is fulfilled when an expected NSNotification is received

 @param name The name of the awaited notification
 @param timeout The maximum amount of float seconds to wait for the expectation
 @return The appropriate waiter result
 */
+ (XCTWaiterResult)waitForNotificationWithName:(NSNotificationName)name
                                       timeout:(NSTimeInterval)timeout;

/**
 Creates an expectation that is fulfilled when an expected Darwin notification is received

 @param name The name of the awaited notification
 @param timeout The maximum amount of float seconds to wait for the expectation
 @return The appropriate waiter result
 */
+ (XCTWaiterResult)waitForDarwinNotificationWithName:(NSString *)name
                                             timeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
