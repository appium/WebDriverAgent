/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/FBXCElementSnapshotWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBMinMax)

/*! Minimum value (minValue) – may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSNumber *fb_minValue;

/*! Maximum value (maxValue) - may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSNumber *fb_maxValue;

@end

@interface FBXCElementSnapshotWrapper (FBMinMax)

/*! Minimum value (minValue) – may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSNumber *fb_minValue;

/*! Maximum value (maxValue) - may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSNumber *fb_maxValue;

@end

NS_ASSUME_NONNULL_END
