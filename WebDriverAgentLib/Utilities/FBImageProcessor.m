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

    UIImage *uiImage = [UIImage imageWithData:nextImageData];
    UIImage *thumbnail = [self.class fixedImageWithImage:uiImage
                                           scalingFactor:scalingFactor
                                      desiredOrientation:uiImage.imageOrientation];
    completionHandler(nil == thumbnail
                      ? nextImageData
                        : UIImageJPEGRepresentation(thumbnail, FBMaxCompressionQuality));
  });
#pragma clang diagnostic pop
}

+ (nullable UIImage *)fixedImageWithImage:(nullable UIImage *)image
                            scalingFactor:(CGFloat)scalingFactor
                       desiredOrientation:(UIImageOrientation)orientation
{
  BOOL usesScaling = scalingFactor > 0.0 && scalingFactor < FBMaxScalingFactor;
  if (nil == image || (image.imageOrientation == UIImageOrientationUp && !usesScaling)) {
    return image;
  }
  
  CGSize scaledSize = CGSizeMake(image.size.width * scalingFactor, image.size.height * scalingFactor);
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:scaledSize];
  UIImage *uiImage = [UIImage imageWithCGImage:(CGImageRef)image.CGImage
                                         scale:image.scale
                                   orientation:orientation];
  UIImage *resultImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
    [uiImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
  }];
  return resultImage;
}

- (nullable NSData *)scaledImageWithData:(NSData *)imageData
                                     uti:(UTType *)uti
                           scalingFactor:(CGFloat)scalingFactor
                      compressionQuality:(CGFloat)compressionQuality
                                   error:(NSError **)error
{
  UIImage *uiImage = [UIImage imageWithData:imageData];
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
  UIImage *resultImage = [self.class fixedImageWithImage:uiImage
                                           scalingFactor:scalingFactor
                                      desiredOrientation:orientation];
  if (nil == resultImage) {
    return imageData;
  }
  return [uti conformsToType:UTTypePNG]
    ? UIImagePNGRepresentation(resultImage)
    : UIImageJPEGRepresentation(resultImage, compressionQuality);
}

@end
