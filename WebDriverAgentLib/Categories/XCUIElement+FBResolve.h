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

/**
 Returns element instance based on query by element's UUID rather than any other attributes, which
 might be a subject of change during the application life cycle. The UUID is calculated based on the PID
 of the application to which this particular element belongs and the identifier of the underlying AXElement
 instance. That usually guarantees the same element is always going to be matched in scope of the parent
 application independently of its current attribute values.
 Example: We have an element X with value Y. Our locator looks like 'value == Y'. Normally, if the element's
 value is changed to Z and we try to reuse this cached instance of it then a StaleElement error is thrown.
 Although, if the cached element instance is the one returned by this API call then the same element
 is going to be matched and no staleness exception will be thrown.

 @return Either the same element instance if `fb_isResolvedNatively` was set to NO (usually the cache for elements
 matched by xpath locators) or the stable instance of the self element based on the query by element's UUID.
 */
- (XCUIElement *)fb_stableInstance;

@end

NS_ASSUME_NONNULL_END
