/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/XCUIElement.h>

NS_ASSUME_NONNULL_BEGIN

#if !TARGET_OS_TV

@interface XCUIElement (FBForceTouch)

/**
 Performs force touch on element
 
 @param relativeCoordinate hit point coordinate relative to the current element position.
 nil value means to use the default element hit point
 @param pressure The pressure of the force touch – valid values are [0, touch.maximumPossibleForce]
 nil value would use the default pressure value
 @param duration The duration of the gesture in float seconds
 nil value would use the default duration value
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_forceTouchCoordinate:(nullable NSValue *)relativeCoordinate
                       pressure:(nullable NSNumber *)pressure
                       duration:(nullable NSNumber *)duration
                          error:(NSError **)error;

@end

#endif

NS_ASSUME_NONNULL_END
