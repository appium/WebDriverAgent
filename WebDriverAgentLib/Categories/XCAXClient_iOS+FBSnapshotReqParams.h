/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "XCAXClient_iOS.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FBSnapshotMaxChildrenKey;
extern NSString *const FBSnapshotMaxDepthKey;

/**
 * Sets or overrides a custom snapshot request parameter by name.
 */
void FBSetCustomParameterForElementSnapshot (NSString* name, id value);

/**
 * Removes a previously configured custom snapshot request parameter by name.
 */
void FBRemoveCustomParameterForElementSnapshot (NSString* name);

id __nullable FBGetCustomParameterForElementSnapshot (NSString *name);

@interface XCAXClient_iOS (FBSnapshotReqParams)

@end

NS_ASSUME_NONNULL_END
