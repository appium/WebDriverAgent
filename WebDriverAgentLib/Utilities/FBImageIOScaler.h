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
 Scales images and compresses it to JPEG using Image I/O
 It allows to enqueue only a single screenshot. If a new one arrives before the currently queued gets discared
 */
@interface FBImageIOScaler : NSObject

/**
 @param scalingFactor the scaling factor (between 1 and 100) to use. A value of 100 won't perform scaling at all
 @param compressionQuality the compression quality of the JPEG output image
 */
- (id)initWithScalingFactor:(NSUInteger)scalingFactor compressionQuality:(NSUInteger)compressionQuality;

/**
 Puts the passed image on the queue and dispatches a scaling operation. If there is already a image on the
 queue it will be replaced with the new one
 @param image The image to scale down
 @param completionHandler called after successfully scaling down an image
 */
- (void)submitImage:(NSData *)image completionHandler:(void(^)(NSData *scaled))completionHandler;

@end

NS_ASSUME_NONNULL_END
