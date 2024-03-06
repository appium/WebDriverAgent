/**
 *
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FBScreenRecordingPromise;

@interface FBScreenRecordingContainer : NSObject

/** The amount of video FPS */
@property (readonly, nonatomic) NSUInteger fps;
/** Codec to use, where 0 is h264, 1 - HEVC */
@property (readonly, nonatomic) long long codec;
/** Keep the currently active screen resording promise. Equals to nil if no active screen recordings are running */
@property (readonly, nonatomic, nullable) FBScreenRecordingPromise* screenRecordingPromise;
/** The timestamp of the video startup as Unix float seconds  */
@property (readonly, nonatomic, nullable) NSNumber *startedAt;

/**
@return singleton instance
 */
+ (instancetype)sharedInstance;

/**
 Keeps current screen recording promise

 @param screenRecordingPromise a promise to set
 @param fps FPS value
 @param codec Codec value
 */
- (void)storeScreenRecordingPromise:(FBScreenRecordingPromise *)screenRecordingPromise
                                fps:(NSUInteger)fps
                              codec:(long long)codec;
/**
 Resets the current screen recording promise
 */
- (void)reset;

/**
 Transforms the container content to a dictionary.

 @return May return nil if no screen recording is currently running
 */
- (nullable NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
