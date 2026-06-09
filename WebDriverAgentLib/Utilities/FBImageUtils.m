/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBImageUtils.h"

#import <ImageIO/ImageIO.h>

#import "FBMacros.h"
#import "FBConfiguration.h"

// https://en.wikipedia.org/wiki/List_of_file_signatures
static uint8_t PNG_MAGIC[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
static const NSUInteger PNG_MAGIC_LEN = 8;
static uint8_t JPG_MAGIC[] = { 0xff, 0xd8, 0xff };
static const NSUInteger JPG_MAGIC_LEN = 3;

BOOL FBIsPngImage(NSData *imageData)
{
  if (nil == imageData || [imageData length] < PNG_MAGIC_LEN) {
    return NO;
  }

  static NSData* pngMagicStartData = nil;
  static dispatch_once_t oncePngToken;
  dispatch_once(&oncePngToken, ^{
    pngMagicStartData = [NSData dataWithBytesNoCopy:(void*)PNG_MAGIC length:PNG_MAGIC_LEN freeWhenDone:NO];
  });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
  NSRange range = [imageData rangeOfData:pngMagicStartData options:kNilOptions range:NSMakeRange(0, PNG_MAGIC_LEN)];
#pragma clang diagnostic pop
  return range.location != NSNotFound;
}

NSData *FBToPngData(NSData *imageData) {
  if (nil == imageData || [imageData length] < PNG_MAGIC_LEN) {
    return nil;
  }
  if (FBIsPngImage(imageData)) {
    return imageData;
  }

  UIImage *image = [UIImage imageWithData:imageData];
  return nil == image ? nil : (NSData *)UIImagePNGRepresentation(image);
}

BOOL FBIsJpegImage(NSData *imageData)
{
  if (nil == imageData || [imageData length] < JPG_MAGIC_LEN) {
    return NO;
  }

  static NSData* jpgMagicStartData = nil;
  static dispatch_once_t onceJpgToken;
  dispatch_once(&onceJpgToken, ^{
    jpgMagicStartData = [NSData dataWithBytesNoCopy:(void*)JPG_MAGIC length:JPG_MAGIC_LEN freeWhenDone:NO];
  });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
  NSRange range = [imageData rangeOfData:jpgMagicStartData options:kNilOptions range:NSMakeRange(0, JPG_MAGIC_LEN)];
#pragma clang diagnostic pop
  return range.location != NSNotFound;
}

NSData *FBToJpegData(NSData *imageData, CGFloat compressionQuality) {
  if (nil == imageData || [imageData length] < JPG_MAGIC_LEN) {
    return nil;
  }
  if (FBIsJpegImage(imageData)) {
    return imageData;
  }
  
  UIImage *image = [UIImage imageWithData:imageData];
  return nil == image ? nil : (NSData *)UIImageJPEGRepresentation(image, compressionQuality);
}

CGImageRef FBCreateOrientedCGImageFromData(NSData *imageData) {
  if (nil == imageData) {
    return NULL;
  }
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
  if (NULL == source) {
    return NULL;
  }

  NSInteger orientation = 1;
  size_t maxPixelSize = 0;
  NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
  if (nil != properties) {
    NSNumber *orientationValue = properties[(__bridge NSString *)kCGImagePropertyOrientation];
    if (nil != orientationValue) {
      orientation = orientationValue.integerValue;
    }
    NSNumber *pixelWidth = properties[(__bridge NSString *)kCGImagePropertyPixelWidth];
    NSNumber *pixelHeight = properties[(__bridge NSString *)kCGImagePropertyPixelHeight];
    maxPixelSize = MAX(pixelWidth.unsignedLongValue, pixelHeight.unsignedLongValue);
  }

  CGImageRef image;
  if (orientation <= 1) {
    // Already upright (or unknown orientation): decode the pixels as-is.
    image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
  } else {
    // Bake the EXIF orientation into the pixels. A raw H.264/H.265 stream cannot carry the
    // orientation tag, so landscape screenshots would otherwise be delivered rotated.
    NSMutableDictionary *options = [@{
      (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
      (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
    } mutableCopy];
    if (maxPixelSize > 0) {
      // Match the original resolution so the "thumbnail" is full size, just reoriented.
      options[(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize] = @(maxPixelSize);
    }
    image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (NULL == image) {
      image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    }
  }
  CFRelease(source);
  return image;
}
