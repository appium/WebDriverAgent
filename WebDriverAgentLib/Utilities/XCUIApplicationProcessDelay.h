/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 In certain cases WebDriverAgent fails to create a session because -[XCUIApplication launch] doesn't return
 since it waits for the target app to be quiescenced.
 The reason for this seems to be that 'testmanagerd' doesn't send the events WebDriverAgent is waiting for.
 The expected events would trigger calls to '-[XCUIApplicationProcess setEventLoopHasIdled:]' and
 '-[XCUIApplicationProcess setAnimationsHaveFinished:]', which are the properties that are checked to
 determine whether an app has quiescenced or not.
 Delaying the call to on of the setters can fix this issue.
 */
@interface XCUIApplicationProcessDelay : NSObject

/**
 Delays the invocation of '-[XCUIApplicationProcess setEventLoopHasIdled:]' by the timer interval passed
 @param delay The duration of the sleep before the original method is called
 */
+ (void)setEventLoopHasIdledDelay:(NSTimeInterval)delay;

/**
 Disables the delayed invocation of '-[XCUIApplicationProcess setEventLoopHasIdled:]'.
 */
+ (void)disableEventLoopDelay;

@end

NS_ASSUME_NONNULL_END
