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

/**
 Checks if the element is a text field

 @param elementType XCTest element type
 @return YES if the elemnt is a text field
 */
BOOL FBDoesElementSupportInnerText(XCUIElementType elementType);

NS_ASSUME_NONNULL_END
