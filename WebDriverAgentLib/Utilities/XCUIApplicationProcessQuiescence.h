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
 This class allows disabling/enabling the usage of application launch quiescence validation.
 */
@interface XCUIApplicationProcessQuiescence : NSObject

/**
 Set the usage of application quiescence validation (defaults to NO).
 */
+ (void)setQuiescenceCheck:(BOOL)value;

@end

NS_ASSUME_NONNULL_END
