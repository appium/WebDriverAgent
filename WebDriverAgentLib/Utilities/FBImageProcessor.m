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

    // We do not want this value to be too high because then we get images larger in size than original ones
    // Although, we also don't want to lose too much of the quality on recompression
    CGFloat recompressionQuality = MAX(0.9,
                                       MIN(FBMaxCompressionQuality, FBConfiguration.mjpegServerScreenshotQuality / 100.0));
    NSData *thumbnailData = [self.class fixedImageDataWithImageData:nextImageData
                                                      scalingFactor:scalingFactor
                                                                uti:UTTypeJPEG
                                                 compressionQuality:recompressionQuality
    // iOS always returns screnshots in portrait orientation, but puts the real value into the metadata
    // Use it with care. See https://github.com/appium/WebDriverAgent/pull/812
                                                     fixOrientation:FBConfiguration.mjpegShouldFixOrientation
                                                 desiredOrientation:nil];
    completionHandler(thumbnailData ?: nextImageData);
  });
#pragma clang diagnostic pop
}

+ (nullable NSData *)fixedImageDataWithImageData:(NSData *)imageData
                                   scalingFactor:(CGFloat)scalingFactor
                                             uti:(UTType *)uti
                              compressionQuality:(CGFloat)compressionQuality
                                  fixOrientation:(BOOL)fixOrientation
                              desiredOrientation:(nullable NSNumber *)orientation
{
  scalingFactor = MAX(FBMinScalingFactor, MIN(FBMaxScalingFactor, scalingFactor));
  BOOL usesScaling = scalingFactor > 0.0 && scalingFactor < FBMaxScalingFactor;
  @autoreleasepool {
    if (!usesScaling && !fixOrientation) {
      return [uti conformsToType:UTTypePNG] ? FBToPngData(imageData) : FBToJpegData(imageData, compressionQuality);
    }
  
    UIImage *image = [UIImage imageWithData:imageData];
    if (nil == image
        || ((image.imageOrientation == UIImageOrientationUp || !fixOrientation) && !usesScaling)) {
      return [uti conformsToType:UTTypePNG] ? FBToPngData(imageData) : FBToJpegData(imageData, compressionQuality);
    }
    
    CGSize scaledSize = CGSizeMake(image.size.width * scalingFactor, image.size.height * scalingFactor);
    if (!fixOrientation && usesScaling) {
      dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
      __block UIImage *result = nil;
      [image prepareThumbnailOfSize:scaledSize
                  completionHandler:^(UIImage * _Nullable thumbnail) {
        result = thumbnail;
        dispatch_semaphore_signal(semaphore);
      }];
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
      if (nil == result) {
        return [uti conformsToType:UTTypePNG] ? FBToPngData(imageData) : FBToJpegData(imageData, compressionQuality);
      }
      return [uti conformsToType:UTTypePNG]
        ? UIImagePNGRepresentation(result)
        : UIImageJPEGRepresentation(result, compressionQuality);
    }
  
    UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
    format.scale = scalingFactor;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:scaledSize
                                                                               format:format];
    UIImageOrientation desiredOrientation = orientation == nil
      ? image.imageOrientation
      : (UIImageOrientation)orientation.integerValue;
    UIImage *uiImage = [UIImage imageWithCGImage:(CGImageRef)image.CGImage
                                           scale:image.scale
                                     orientation:desiredOrientation];
    return [uti conformsToType:UTTypePNG]
      ? [renderer PNGDataWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [uiImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
      }]
      : [renderer JPEGDataWithCompressionQuality:compressionQuality
                                         actions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [uiImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
      }];
  }
}

- (nullable NSData *)scaledImageWithData:(NSData *)imageData
                                     uti:(UTType *)uti
                           scalingFactor:(CGFloat)scalingFactor
                      compressionQuality:(CGFloat)compressionQuality
                                   error:(NSError **)error
{
  NSNumber *orientation = nil;
#if !TARGET_OS_TV
  if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationPortrait) {
    orientation = @(UIImageOrientationUp);
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationPortraitUpsideDown) {
    orientation = @(UIImageOrientationDown);
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationLandscapeLeft) {
    orientation = @(UIImageOrientationRight);
  } else if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationLandscapeRight) {
    orientation = @(UIImageOrientationLeft);
  }
#endif
  NSData *resultData = [self.class fixedImageDataWithImageData:imageData
                                                 scalingFactor:scalingFactor
                                                           uti:uti
                                            compressionQuality:compressionQuality
                                                fixOrientation:YES
                                            desiredOrientation:orientation];
  return resultData ?: imageData;
}

@end
