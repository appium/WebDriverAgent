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

@interface FBScreenRecordingRequest : NSObject

/** The amount of video FPS */
@property (readonly, nonatomic) NSUInteger fps;
/** Codec to use, where 0 is h264, 1 - HEVC */
@property (readonly, nonatomic) long long codec;

/**
 Creates a custom wrapper for a screen recording reqeust

 @param fps FPS value, see baove
 @param codec Codex value, see above
 */
- (instancetype)initWithFps:(NSUInteger)fps codec:(long long)codec;

/**
 Transforms the current wrapper instance to a native object,
 which is ready to be passed to XCTest APIs

 @param error If there was a failure converting the instance to a native object
 @returns Native object instance
 */
- (nullable id)toNativeRequestWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
