/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class UTType;

NS_ASSUME_NONNULL_BEGIN

// Those values define the allowed ranges for the scaling factor and compression quality settings
extern const CGFloat FBMinScalingFactor;
extern const CGFloat FBMaxScalingFactor;
extern const CGFloat FBMinCompressionQuality;
extern const CGFloat FBMaxCompressionQuality;

@interface FBImageProcessor : NSObject

/**
 Puts the passed image on the queue and dispatches a scaling operation. If there is already a image on the
 queue it will be replaced with the new one

 @param image The image to scale down
 @param completionHandler called after successfully scaling down an image
 @param scalingFactor the scaling factor in range 0.01..1.0. A value of 1.0 won't perform scaling at all
 */
- (void)submitImageData:(NSData *)image
          scalingFactor:(CGFloat)scalingFactor
      completionHandler:(void (^)(NSData *))completionHandler;

/**
 Scales and crops the source image

 @param image The source image data
 @param uti Either UTTypePNG or UTTypeJPEG
 @param scalingFactor Scaling factor in range 0.01..1.0. A value of 1.0 won't perform scaling at all
 @param compressionQuality the compression quality in range 0.0..1.0 (0.0 for max. compression and 1.0 for lossless compression).
 Only works if UTI is set to kUTTypeJPEG
 @param error The actual error instance if the returned result is nil
 @returns Processed image data compressed according to the given UTI or nil in case of a failure
 */
- (nullable NSData *)scaledImageWithData:(NSData *)image
                                     uti:(UTType *)uti
                           scalingFactor:(CGFloat)scalingFactor
                      compressionQuality:(CGFloat)compressionQuality
                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
