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

@interface XCUIElement (FBResolve)

/*! This property is always true unless the element gets resolved by its internal UUID (e.g. results of an xpath query) */
@property (nullable, nonatomic) NSNumber *fb_isResolvedNatively;

- (XCUIElement *)fb_stableInstance;

@end

NS_ASSUME_NONNULL_END
