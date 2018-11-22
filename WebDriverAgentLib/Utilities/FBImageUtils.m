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

BOOL FBIsJpegImage(NSData *imageData)
{
  static const NSUInteger magicLen = 2;
  if (nil == imageData || [imageData length] < magicLen) {
    return NO;
  }

  static NSData* magicStartData = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    static uint8_t magic[] = { 0xff, 0xd8 };
    magicStartData = [NSData dataWithBytesNoCopy:(void*)magic length:magicLen freeWhenDone:NO];
  });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
  NSRange range = [imageData rangeOfData:magicStartData options:kNilOptions range:NSMakeRange(0, magicLen)];
#pragma clang diagnostic pop
  return range.location != NSNotFound;
}

NSData *FBAdjustScreenshotOrientationForApplication(NSData *screenshotData, UIInterfaceOrientation orientation)
{
  UIImage *image = [UIImage imageWithData:screenshotData];
  UIImageOrientation imageOrientation;
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
    return (NSData *)UIImagePNGRepresentation(image);
  }

  UIGraphicsBeginImageContext(CGSizeMake(image.size.width, image.size.height));
  [[UIImage imageWithCGImage:(CGImageRef)[image CGImage] scale:1.0 orientation:imageOrientation]
   drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
  UIImage *fixedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  // The resulting data should be a PNG image
  return (NSData *)UIImagePNGRepresentation(fixedImage);
}
