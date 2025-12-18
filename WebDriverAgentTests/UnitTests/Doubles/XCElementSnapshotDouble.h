/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

@interface XCElementSnapshotDouble : NSObject<XCUIElementAttributes>
@property (readwrite, nullable) id value;
@property (readwrite, nullable, copy) NSString *label;
@property (nonatomic, assign) UIAccessibilityTraits traits;
@property (readwrite, nullable) NSMutableDictionary *additionalAttributes;
@end
