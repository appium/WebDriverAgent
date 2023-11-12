/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBImageUtils.h"
@import UniformTypeIdentifiers;

#import "FBLogger.h"
#import "FBMacros.h"
#import "FBConfiguration.h"

static uint8_t PNG_MAGIC[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
static const NSUInteger PNG_MAGIC_LEN = 8;

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

@implementation UIImage (FBImageUtils)

- (UIImage *)imageByFixingOrientation
{
  if (self.imageOrientation == UIImageOrientationUp) {
    return self;
  }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
#pragma clang diagnostic ignored "-Wswitch"
  CGAffineTransform transform = CGAffineTransformIdentity;
  switch (self.imageOrientation) {
    case UIImageOrientationDown:
    case UIImageOrientationDownMirrored:
      transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height);
      transform = CGAffineTransformRotate(transform, M_PI);
      break;
    case UIImageOrientationLeft:
    case UIImageOrientationLeftMirrored:
      transform = CGAffineTransformTranslate(transform, self.size.width, 0);
      transform = CGAffineTransformRotate(transform, M_PI_2);
      break;
    case UIImageOrientationRight:
    case UIImageOrientationRightMirrored:
      transform = CGAffineTransformTranslate(transform, 0, self.size.height);
      transform = CGAffineTransformRotate(transform, -M_PI_2);
      break;
  }
  
  switch (self.imageOrientation) {
    case UIImageOrientationUpMirrored:
    case UIImageOrientationDownMirrored:
      transform = CGAffineTransformTranslate(transform, self.size.width, 0);
      transform = CGAffineTransformScale(transform, -1, 1);
      break;
    case UIImageOrientationLeftMirrored:
    case UIImageOrientationRightMirrored:
      transform = CGAffineTransformTranslate(transform, self.size.height, 0);
      transform = CGAffineTransformScale(transform, -1, 1);
      break;
  }
  
  CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t) self.size.width, (size_t) self.size.height,
                                           CGImageGetBitsPerComponent(self.CGImage), 0,
                                           CGImageGetColorSpace(self.CGImage),
                                           CGImageGetBitmapInfo(self.CGImage));
  CGContextConcatCTM(ctx, transform);
  switch (self.imageOrientation) {
    case UIImageOrientationLeft:
    case UIImageOrientationLeftMirrored:
    case UIImageOrientationRight:
    case UIImageOrientationRightMirrored:
      CGContextDrawImage(ctx, CGRectMake(0, 0, self.size.height,self.size.width), self.CGImage);
      break;
    default:
      CGContextDrawImage(ctx, CGRectMake(0, 0, self.size.width,self.size.height), self.CGImage);
      break;
  }
#pragma clang diagnostic pop

  CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
  UIImage *img = [UIImage imageWithCGImage:cgimg];
  CGContextRelease(ctx);
  CGImageRelease(cgimg);
  return img;
}

@end
