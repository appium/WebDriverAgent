/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBImageUtils.h"

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

#if TARGET_OS_TV
NSData *FBAdjustScreenshotOrientationForApplication(NSData *screenshotData)
{
  return FBToPngData(screenshotData);
}
#else
NSData *FBAdjustScreenshotOrientationForApplication(NSData *screenshotData, UIInterfaceOrientation orientation)
{
  if (nil == screenshotData) {
    return nil;
  }

  UIImageOrientation imageOrientation;
  if (FBConfiguration.screenshotOrientation == UIInterfaceOrientationUnknown) {
    if (SYSTEM_VERSION_LESS_THAN(@"11.0")) {
      // In iOS < 11.0 screenshots are already adjusted properly
      imageOrientation = UIImageOrientationUp;
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
      imageOrientation = UIImageOrientationLeft;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
      imageOrientation = UIImageOrientationRight;
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
      imageOrientation = UIImageOrientationDown;
    } else {
      return FBToPngData(screenshotData);
    }
  } else {
    switch (FBConfiguration.screenshotOrientation) {
      case UIInterfaceOrientationPortraitUpsideDown:
        imageOrientation = UIImageOrientationDown;
        break;
      case UIInterfaceOrientationLandscapeRight:
        imageOrientation = UIImageOrientationLeft;
        break;
      case UIInterfaceOrientationLandscapeLeft:
        imageOrientation = UIImageOrientationRight;
        break;
      default:
        imageOrientation = UIImageOrientationUp;
        break;
    }
  }

  UIImage *image = [UIImage imageWithData:screenshotData];
  if (nil == image) {
    return nil;
  }
  UIGraphicsBeginImageContext(CGSizeMake(image.size.width, image.size.height));
  [[UIImage imageWithCGImage:(CGImageRef)[image CGImage] scale:1.0 orientation:imageOrientation]
   drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
  UIImage *fixedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  // The resulting data should be a PNG image
  return nil == fixedImage ? nil : (NSData *)UIImagePNGRepresentation(fixedImage);
}
#endif
