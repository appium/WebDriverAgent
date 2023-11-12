/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBImageProcessor.h"

#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
@import UniformTypeIdentifiers;

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBImageUtils.h"
#import "FBLogger.h"

const CGFloat FBMinScalingFactor = 0.01f;
const CGFloat FBMaxScalingFactor = 1.0f;
const CGFloat FBMinCompressionQuality = 0.0f;
const CGFloat FBMaxCompressionQuality = 1.0f;

@interface FBImageProcessor ()

@property (nonatomic) NSData *nextImage;
@property (nonatomic, readonly) NSLock *nextImageLock;
@property (nonatomic, readonly) dispatch_queue_t scalingQueue;

@end

@implementation FBImageProcessor

- (id)init
{
  self = [super init];
  if (self) {
    _nextImageLock = [[NSLock alloc] init];
    _scalingQueue = dispatch_queue_create("image.scaling.queue", NULL);
  }
  return self;
}

- (void)submitImageData:(NSData *)image
          scalingFactor:(CGFloat)scalingFactor
     compressionQuality:(CGFloat)compressionQuality
      completionHandler:(void (^)(NSData *))completionHandler
{
  [self.nextImageLock lock];
  if (self.nextImage != nil) {
    [FBLogger verboseLog:@"Discarding screenshot"];
  }
  scalingFactor = MAX(FBMinScalingFactor, MIN(FBMaxScalingFactor, scalingFactor));
  compressionQuality = MAX(FBMinCompressionQuality, MIN(FBMaxCompressionQuality, compressionQuality));
  self.nextImage = image;
  [self.nextImageLock unlock];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcompletion-handler"
  dispatch_async(self.scalingQueue, ^{
    [self.nextImageLock lock];
    NSData *nextImageData = self.nextImage;
    self.nextImage = nil;
    [self.nextImageLock unlock];
    if (nextImageData == nil) {
      return;
    }

    NSError *error = nil;
    NSData *processedImageData = [self processedJpegImageWithData:nextImageData
                                                    scalingFactor:scalingFactor
                                               compressionQuality:compressionQuality
                                                            error:&error];
    if (nil == processedImageData) {
      [FBLogger logFmt:@"%@", error.description];
      return;
    }
    completionHandler(processedImageData);
  });
#pragma clang diagnostic pop
}

// This method is more optimized for JPEG scaling
// and should be used in `submitImage` API, while the `scaledImageWithData`
// one is more generic
- (nullable NSData*)processedJpegImageWithData:(NSData *)imageData
                                 scalingFactor:(CGFloat)scalingFactor
                            compressionQuality:(CGFloat)compressionQuality
                                         error:(NSError **)error
{
  CGImageSourceRef imageDataRef = CGImageSourceCreateWithData((CFDataRef)imageData, nil);
  
  NSDictionary *options = @{
    (const NSString *)kCGImageSourceShouldCache: @(NO)
  };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageDataRef, 0, (CFDictionaryRef)options);
  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelHeight];
  CGImagePropertyOrientation orientation = (CGImagePropertyOrientation)[[(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyOrientation] integerValue];
  CGSize size = CGSizeMake([width floatValue], [height floatValue]);
  CFRelease(properties);
  
  BOOL usesScaling = fabs(FBMaxScalingFactor - scalingFactor) > DBL_EPSILON && scalingFactor > 0;
  
  CGImageRef resultImage = NULL;
  if (orientation != kCGImagePropertyOrientationUp) {
    // Scale and fix orientation.
    // Unfortunately CGContextDrawImage is known to be not very perfomant,
    // so consider finding a faster API of for images scale/rotation.
    resultImage = CGImageSourceCreateImageAtIndex(imageDataRef, 0, NULL);
    CGImageRef originalImage = resultImage;
    size_t bitsPerComponent = CGImageGetBitsPerComponent(originalImage);
    BOOL shouldSwapWidthAndHeight = orientation == kCGImagePropertyOrientationLeft
      || orientation == kCGImagePropertyOrientationRight;
    CGSize scaledSize = usesScaling
      ? CGSizeMake(width.floatValue * scalingFactor, height.floatValue * scalingFactor)
      : size;
    size_t contextWidth = (size_t) (shouldSwapWidthAndHeight ? scaledSize.height : scaledSize.width);
    size_t contextHeight = (size_t) (shouldSwapWidthAndHeight ? scaledSize.width : scaledSize.height);
    CGContextRef ctx = CGBitmapContextCreate(
                                             NULL,
                                             contextWidth,
                                             contextHeight,
                                             bitsPerComponent,
                                             contextWidth * CGImageGetBitsPerPixel(originalImage) / bitsPerComponent,
                                             CGImageGetColorSpace(originalImage),
                                             CGImageGetBitmapInfo(originalImage));
    if (orientation == kCGImagePropertyOrientationLeft) {
      CGContextRotateCTM(ctx, M_PI_2);
      CGContextTranslateCTM(ctx, 0, -scaledSize.height);
    } else if (orientation == kCGImagePropertyOrientationRight) {
      CGContextRotateCTM(ctx, -M_PI_2);
      CGContextTranslateCTM(ctx, -scaledSize.width, 0);
    } else if (orientation == kCGImagePropertyOrientationDown) {
      CGContextTranslateCTM(ctx, scaledSize.width, scaledSize.height);
      CGContextRotateCTM(ctx, -M_PI);
    }
    CGContextDrawImage(ctx, CGRectMake(0, 0, scaledSize.width, scaledSize.height), originalImage);
    resultImage = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGImageRelease(originalImage);
  } else if (usesScaling) {
    // Only scale.
    // ImageIO is known to perform better than the above,
    // although it cannot rotate the canvas.
    CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;
    CFDictionaryRef params = (__bridge CFDictionaryRef)@{
      (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
      (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
      (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
    };
    resultImage = CGImageSourceCreateThumbnailAtIndex(imageDataRef, 0, params);
  }
  CFRelease(imageDataRef);
  if (NULL == resultImage) {
    if (orientation != kCGImagePropertyOrientationUp || usesScaling) {
      // This is suboptimal, but better to have something than nothing at all
      // NSLog(@"The image cannot be preprocessed. Passing it as is");
    }
    // No scaling and/or orientation fixing was neecessary
    return imageData;
  }
  
  NSData *resData = [self jpegDataWithImage:resultImage
                         compressionQuality:compressionQuality];
  CGImageRelease(resultImage);
  if (nil == resData) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to compress the image to JPEG format"]
     buildError:error];
  }
  return resData;
}

- (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef
                    compressionQuality:(CGFloat)compressionQuality
{
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData(
                                                                            (__bridge CFMutableDataRef) newImageData,
                                                                            (__bridge CFStringRef) UTTypeJPEG.identifier,
                                                                            1,
                                                                            NULL);
  CFDictionaryRef compressionOptions = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageDestinationLossyCompressionQuality: @(compressionQuality)
  };
  CGImageDestinationAddImage(imageDestination, imageRef, compressionOptions);
  if(!CGImageDestinationFinalize(imageDestination)) {
    [FBLogger log:@"Failed to write the image"];
    newImageData = nil;
  }
  CFRelease(imageDestination);
  return newImageData;
}

- (nullable NSData *)scaledImageWithData:(NSData *)image
                                     uti:(UTType *)uti
                                    rect:(CGRect)rect
                           scalingFactor:(CGFloat)scalingFactor
                      compressionQuality:(CGFloat)compressionQuality
                                   error:(NSError **)error
{
  UIImage *uiImage = [UIImage imageWithData:image];
  CGSize size = uiImage.size;
  CGSize scaledSize = CGSizeMake(size.width * scalingFactor, size.height * scalingFactor);
  UIGraphicsBeginImageContext(scaledSize);
  UIImageOrientation orientation = uiImage.imageOrientation;
#if !TARGET_OS_TV
  if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationPortrait) {
    orientation = UIImageOrientationUp;
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationPortraitUpsideDown) {
    orientation = UIImageOrientationDown;
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationLandscapeLeft) {
    orientation = UIImageOrientationRight;
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationLandscapeRight) {
    orientation = UIImageOrientationLeft;
  }
#endif
  uiImage = [UIImage imageWithCGImage:(CGImageRef)uiImage.CGImage
                                scale:uiImage.scale
                          orientation:orientation];
  [uiImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
  UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  if (!CGRectIsNull(rect)) {
    UIGraphicsBeginImageContext(rect.size);
    [resultImage drawAtPoint:CGPointMake(-rect.origin.x, -rect.origin.y)];
    resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }

  return [uti conformsToType:UTTypePNG]
    ? UIImagePNGRepresentation(resultImage)
    : UIImageJPEGRepresentation(resultImage, compressionQuality);
}

+ (CGSize)imageSizeWithImage:(CGImageSourceRef)imageSource
{
  NSDictionary *options = @{
    (const NSString *)kCGImageSourceShouldCache: @(NO)
  };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelHeight];
  CGSize size = CGSizeMake([width floatValue], [height floatValue]);
  CFRelease(properties);
  return size;
}

@end
