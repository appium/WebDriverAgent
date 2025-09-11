/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Converts accessibility traits bitmask to an array of string representations
 @param traits The accessibility traits bitmask
 @return Array of strings representing the accessibility traits
 */
NSArray<NSString *> *FBAccessibilityTraitsToStringsArray(unsigned long long traits);

NS_ASSUME_NONNULL_END
