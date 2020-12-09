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
#import <MobileCoreServices/MobileCoreServices.h>
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

- (void)submitImage:(NSData *)image scalingFactor:(CGFloat)scalingFactor compressionQuality:(CGFloat)compressionQuality completionHandler:(void (^)(NSData *))completionHandler {
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
    NSData *scaled = [self scaledImageWithImage:next
                                  scalingFactor:scalingFactor
                              compressionQuality:compressionQuality];
    if (scaled == nil) {
      [FBLogger log:@"Could not scale down the image"];
      return;
    }
    completionHandler(scaled);
  });
}

- (nullable NSData *)scaledImageWithImage:(NSData *)image scalingFactor:(CGFloat)scalingFactor compressionQuality:(CGFloat)compressionQuality {
  CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)image, nil);

  CGSize size = [FBImageIOScaler imageSizeWithImage:imageData];
  CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;

  CFDictionaryRef params = (__bridge CFDictionaryRef)@{
                                                       (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
                                                       (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
                                                       (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
                                                       };

  CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(imageData, 0, params);
  if (scaled == nil) {
    [FBLogger log:@"Failed to scale the image"];
    CFRelease(imageData);
    return nil;
  }
  NSData *jpegData = [self jpegDataWithImage:scaled
                           compressionQuality:compressionQuality];
  CGImageRelease(scaled);
  CFRelease(imageData);
  return jpegData;
}

- (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef compressionQuality:(CGFloat)compressionQuality
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
