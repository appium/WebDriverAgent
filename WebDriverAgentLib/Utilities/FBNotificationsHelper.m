/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBNotificationsHelper.h"

@implementation FBNotificationsHelper

+ (XCTWaiterResult)waitForNotificationWithName:(NSNotificationName)name
                                       timeout:(NSTimeInterval)timeout
{
  XCTNSNotificationExpectation *expectation = [[XCTNSNotificationExpectation alloc]
                                               initWithName:name];
  return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout];
}

+ (XCTWaiterResult)waitForDarwinNotificationWithName:(NSString *)name
                                             timeout:(NSTimeInterval)timeout
{
  XCTDarwinNotificationExpectation *expectation = [[XCTDarwinNotificationExpectation alloc]
                                                   initWithNotificationName:name];
  return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout];
}

@end
