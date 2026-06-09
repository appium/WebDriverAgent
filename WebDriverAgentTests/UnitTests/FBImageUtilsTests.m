/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import <ImageIO/ImageIO.h>

#import "FBImageUtils.h"

@interface FBImageUtilsTests : XCTestCase
@end

@implementation FBImageUtilsTests

// Builds a JPEG of the given pixel size that carries the given EXIF orientation tag.
static NSData *FBJpegWithOrientation(size_t width, size_t height, NSInteger orientation)
{
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace,
                                               kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  CGContextSetRGBFillColor(context, 0.2, 0.4, 0.6, 1.0);
  CGContextFillRect(context, CGRectMake(0, 0, width, height));
  CGImageRef image = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);

  NSMutableData *data = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                                                       (__bridge CFStringRef)@"public.jpeg", 1, NULL);
  CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)@{
    (__bridge NSString *)kCGImagePropertyOrientation: @(orientation),
  });
  CGImageDestinationFinalize(destination);
  CFRelease(destination);
  CGImageRelease(image);
  return data;
}

- (void)testUprightOrientationKeepsDimensions
{
  NSData *data = FBJpegWithOrientation(64, 48, 1);
  CGImageRef image = FBCreateOrientedCGImageFromData(data);
  XCTAssertTrue(image != NULL);
  XCTAssertEqual(CGImageGetWidth(image), (size_t)64);
  XCTAssertEqual(CGImageGetHeight(image), (size_t)48);
  CGImageRelease(image);
}

- (void)testRightOrientationSwapsDimensions
{
  // Orientation 6: portrait pixels (48x64) that should display as landscape (64x48).
  NSData *data = FBJpegWithOrientation(48, 64, 6);
  CGImageRef image = FBCreateOrientedCGImageFromData(data);
  XCTAssertTrue(image != NULL);
  XCTAssertEqual(CGImageGetWidth(image), (size_t)64);
  XCTAssertEqual(CGImageGetHeight(image), (size_t)48);
  CGImageRelease(image);
}

- (void)testLeftOrientationSwapsDimensions
{
  // Orientation 8: the other landscape rotation.
  NSData *data = FBJpegWithOrientation(48, 64, 8);
  CGImageRef image = FBCreateOrientedCGImageFromData(data);
  XCTAssertTrue(image != NULL);
  XCTAssertEqual(CGImageGetWidth(image), (size_t)64);
  XCTAssertEqual(CGImageGetHeight(image), (size_t)48);
  CGImageRelease(image);
}

- (void)testNilDataReturnsNull
{
  XCTAssertTrue(FBCreateOrientedCGImageFromData((NSData *)nil) == NULL);
}

@end
