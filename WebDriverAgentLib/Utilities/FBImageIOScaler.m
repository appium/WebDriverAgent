/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBImageIOScaler.h"

#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"

const CGFloat FBMinScalingFactor = 0.01f;
const CGFloat FBMaxScalingFactor = 1.0f;
const CGFloat FBMinCompressionQuality = 0.0f;
const CGFloat FBMaxCompressionQuality = 1.0f;

@interface FBImageIOScaler ()

@property (nonatomic) NSData *nextImage;
@property (nonatomic, readonly) NSLock *nextImageLock;
@property (nonatomic, readonly) dispatch_queue_t scalingQueue;

@end

@implementation FBImageIOScaler

- (id)init
{
  self = [super init];
  if (self) {
    _nextImageLock = [[NSLock alloc] init];
    _scalingQueue = dispatch_queue_create("image.scaling.queue", NULL);
  }
  return self;
}

- (void)submitImage:(NSData *)image
                uti:(NSString *)uti
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

  dispatch_async(self.scalingQueue, ^{
    [self.nextImageLock lock];
    NSData *next = self.nextImage;
    self.nextImage = nil;
    [self.nextImageLock unlock];
    if (next == nil) {
      return;
    }

    NSError *error;
    NSData *scaled = [self scaledJpegImageWithImage:next
                                      scalingFactor:scalingFactor
                                 compressionQuality:compressionQuality
                                              error:&error];
    if (scaled == nil) {
      [FBLogger logFmt:@"%@", error.description];
      return;
    }
    completionHandler(scaled);
  });
}

// This method is more optimized for JPEG scaling
// and should be used in `submitImage` API, while the `scaledImageWithImage`
// one is more generic
- (nullable NSData *)scaledJpegImageWithImage:(NSData *)image
                                scalingFactor:(CGFloat)scalingFactor
                           compressionQuality:(CGFloat)compressionQuality
                                        error:(NSError **)error
{
  CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)image, nil);
  CGSize size = [self.class imageSizeWithImage:imageData];
  CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;
  CFDictionaryRef params = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
    (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
    (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
  };
  CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(imageData, 0, params);
  CFRelease(imageData);
  if (nil == scaled) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to scale the image"]
     buildError:error];
    return nil;
  }
  NSData *resData = [self jpegDataWithImage:scaled
                         compressionQuality:compressionQuality];
  if (nil == resData) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to compress the image to JPEG format"]
     buildError:error];
  }
  CGImageRelease(scaled);
  return resData;
}

- (nullable NSData *)scaledImageWithImage:(NSData *)image
                                      uti:(NSString *)uti
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

  return [uti isEqualToString:(__bridge id)kUTTypePNG]
    ? UIImagePNGRepresentation(resultImage)
    : UIImageJPEGRepresentation(resultImage, compressionQuality);
}

- (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef
                    compressionQuality:(CGFloat)compressionQuality
{
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)newImageData, kUTTypeJPEG, 1, NULL);
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
