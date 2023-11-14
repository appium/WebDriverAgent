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
      completionHandler:(void (^)(NSData *))completionHandler
{
  [self.nextImageLock lock];
  if (self.nextImage != nil) {
    [FBLogger verboseLog:@"Discarding screenshot"];
  }
  scalingFactor = MAX(FBMinScalingFactor, MIN(FBMaxScalingFactor, scalingFactor));
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
    NSData *processedImageData = [self.class processedJpegImageWithData:nextImageData
                                                          scalingFactor:scalingFactor
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
+ (nullable NSData*)processedJpegImageWithData:(NSData *)imageData
                                 scalingFactor:(CGFloat)scalingFactor
                                         error:(NSError **)error
{
  CGImageSourceRef imageDataRef = CGImageSourceCreateWithData((CFDataRef)imageData, nil);
  
  NSDictionary *options = @{
    (const NSString *)kCGImageSourceShouldCache: @(NO)
  };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageDataRef, 0, (CFDictionaryRef)options);
  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelHeight];
  CGImagePropertyOrientation orientation = (CGImagePropertyOrientation) [[(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyOrientation]
                                                                         integerValue];
  CGSize size = CGSizeMake([width doubleValue], [height doubleValue]);
  CFRelease(properties);

  BOOL usesScaling = scalingFactor > 0.0 && scalingFactor < FBMaxScalingFactor;
  CGImageRef resultImage = NULL;
  if (orientation != kCGImagePropertyOrientationUp || usesScaling) {
    CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;
    CFDictionaryRef params = (__bridge CFDictionaryRef)@{
      (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
      (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
      (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
    };
    resultImage = CGImageSourceCreateThumbnailAtIndex(imageDataRef, 0, params);
    // This may be suboptimal, but better to have something than nothing at all
    //    if (NULL == resultImage) {
    //      NSLog(@"The image cannot be preprocessed. Passing it as is");
    //    }
  }
  CFRelease(imageDataRef);
  if (NULL == resultImage) {
    // No scaling and/or orientation fixing was necessary
    return imageData;
  }
  
  NSData *resData = [self.class jpegDataWithImage:resultImage];
  CGImageRelease(resultImage);
  if (nil == resData) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to compress the image to JPEG format"]
     buildError:error];
  }
  return resData;
}

+ (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef
{
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData(
                                                                            (__bridge CFMutableDataRef) newImageData,
                                                                            (__bridge CFStringRef) UTTypeJPEG.identifier,
                                                                            1,
                                                                            NULL);
  CFDictionaryRef compressionOptions = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageDestinationLossyCompressionQuality: @(FBMaxCompressionQuality)
  };
  CGImageDestinationAddImage(imageDestination, imageRef, compressionOptions);
  if (!CGImageDestinationFinalize(imageDestination)) {
    newImageData = nil;
  }
  CFRelease(imageDestination);
  return newImageData.copy;
}

- (nullable NSData *)scaledImageWithData:(NSData *)image
                                     uti:(UTType *)uti
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

  return [uti conformsToType:UTTypePNG]
    ? UIImagePNGRepresentation(resultImage)
    : UIImageJPEGRepresentation(resultImage, compressionQuality);
}

@end
