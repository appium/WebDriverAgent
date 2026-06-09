/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Converts encoded screenshot images into fixed-size 32BGRA pixel buffers that can be
 fed into a VTCompressionSession. The source image is scaled to fit the requested
 dimensions while preserving its aspect ratio; the remaining area is padded with black
 (letterbox/pillarbox), so the produced buffer always has the exact requested size.
 */
@interface FBPixelBufferConverter : NSObject

/** The width of produced pixel buffers in pixels (always even). */
@property (nonatomic, readonly) size_t width;
/** The height of produced pixel buffers in pixels (always even). */
@property (nonatomic, readonly) size_t height;

/**
 Creates a converter producing buffers of the given size. The requested width and height
 are rounded down to the closest non-zero even values, since most video encoders expect
 even dimensions.

 @param width The desired output width in pixels
 @param height The desired output height in pixels
 */
- (instancetype)initWithWidth:(size_t)width height:(size_t)height;

- (instancetype)init NS_UNAVAILABLE;

/**
 Decodes the given encoded image data (JPEG/PNG/HEIC) and renders it into a letterboxed
 32BGRA pixel buffer of the configured size.

 @param imageData Encoded image data
 @param error If there is an error, upon return contains an NSError describing the problem
 @return A retained pixel buffer (the caller owns it and must call CVPixelBufferRelease),
         or NULL in case of a failure
 */
- (nullable CVPixelBufferRef)copyPixelBufferFromImageData:(NSData *)imageData
                                                   error:(NSError **)error CF_RETURNS_RETAINED;

/**
 Renders the given image into a letterboxed 32BGRA pixel buffer of the configured size.

 @param image The source image
 @param error If there is an error, upon return contains an NSError describing the problem
 @return A retained pixel buffer (the caller owns it and must call CVPixelBufferRelease),
         or NULL in case of a failure
 */
- (nullable CVPixelBufferRef)copyPixelBufferFromCGImage:(CGImageRef)image
                                                 error:(NSError **)error CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
