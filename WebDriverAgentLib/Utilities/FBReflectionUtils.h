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
 * Swizzles the implemntation of originalSelector with the swizzledSelector for the given class.
 * Both methods must belong to this class.
 *
 * @param cls The class where to swizzle
 * @param originalSelector original method selector
 * @paramswizzledSelector swizzled method selector
 */
void FBReplaceMethod(Class cls, SEL originalSelector, SEL swizzledSelector);

NS_ASSUME_NONNULL_END
