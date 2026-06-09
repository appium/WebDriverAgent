/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import <ImageIO/ImageIO.h>

#import "FBPixelBufferConverter.h"

@interface FBPixelBufferConverterTests : XCTestCase
@end

@implementation FBPixelBufferConverterTests

static CGImageRef FBCreateSolidImage(size_t width, size_t height, CGFloat red, CGFloat green, CGFloat blue) CF_RETURNS_RETAINED
{
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace,
                                               kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  CGContextSetRGBFillColor(context, red, green, blue, 1.0);
  CGContextFillRect(context, CGRectMake(0, 0, width, height));
  CGImageRef image = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  return image;
}

static void FBReadPixel(CVPixelBufferRef pixelBuffer, size_t x, size_t y, uint8_t *outBGRA)
{
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  const uint8_t *base = (const uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
  const uint8_t *pixel = base + y * bytesPerRow + x * 4;
  outBGRA[0] = pixel[0];
  outBGRA[1] = pixel[1];
  outBGRA[2] = pixel[2];
  outBGRA[3] = pixel[3];
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)testProducesExactEvenDimensions
{
  FBPixelBufferConverter *converter = [[FBPixelBufferConverter alloc] initWithWidth:1280 height:720];
  XCTAssertEqual(converter.width, (size_t)1280);
  XCTAssertEqual(converter.height, (size_t)720);

  CGImageRef image = FBCreateSolidImage(100, 100, 1.0, 0.0, 0.0);
  NSError *error;
  CVPixelBufferRef pixelBuffer = [converter copyPixelBufferFromCGImage:image error:&error];
  CGImageRelease(image);

  XCTAssertTrue(pixelBuffer != NULL, @"%@", error);
  XCTAssertEqual(CVPixelBufferGetWidth(pixelBuffer), (size_t)1280);
  XCTAssertEqual(CVPixelBufferGetHeight(pixelBuffer), (size_t)720);
  XCTAssertEqual(CVPixelBufferGetPixelFormatType(pixelBuffer), (OSType)kCVPixelFormatType_32BGRA);
  CVPixelBufferRelease(pixelBuffer);
}

- (void)testRoundsOddDimensionsDownToEven
{
  FBPixelBufferConverter *converter = [[FBPixelBufferConverter alloc] initWithWidth:101 height:201];
  XCTAssertEqual(converter.width, (size_t)100);
  XCTAssertEqual(converter.height, (size_t)200);
}

- (void)testLetterboxPadsWithBlackAndKeepsContent
{
  // A tall (portrait) source rendered into a wide (landscape) target should be pillarboxed:
  // black bars on the left and right, the red content centered.
  FBPixelBufferConverter *converter = [[FBPixelBufferConverter alloc] initWithWidth:200 height:100];
  CGImageRef image = FBCreateSolidImage(100, 300, 1.0, 0.0, 0.0);
  NSError *error;
  CVPixelBufferRef pixelBuffer = [converter copyPixelBufferFromCGImage:image error:&error];
  CGImageRelease(image);
  XCTAssertTrue(pixelBuffer != NULL, @"%@", error);

  uint8_t corner[4];
  FBReadPixel(pixelBuffer, 1, 50, corner);
  XCTAssertEqual(corner[0], 0, @"Left edge should be black (blue channel)");
  XCTAssertEqual(corner[1], 0, @"Left edge should be black (green channel)");
  XCTAssertEqual(corner[2], 0, @"Left edge should be black (red channel)");

  uint8_t center[4];
  FBReadPixel(pixelBuffer, 100, 50, center);
  XCTAssertEqual(center[0], 0, @"Center blue channel should be 0 for red content");
  XCTAssertEqual(center[1], 0, @"Center green channel should be 0 for red content");
  XCTAssertEqual(center[2], 255, @"Center red channel should be 255 for red content");
  CVPixelBufferRelease(pixelBuffer);
}

- (void)testDecodesEncodedImageData
{
  CGImageRef image = FBCreateSolidImage(64, 48, 0.0, 1.0, 0.0);
  NSMutableData *jpegData = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)jpegData,
                                                                       (__bridge CFStringRef)@"public.jpeg", 1, NULL);
  CGImageDestinationAddImage(destination, image, NULL);
  CGImageDestinationFinalize(destination);
  CFRelease(destination);
  CGImageRelease(image);

  FBPixelBufferConverter *converter = [[FBPixelBufferConverter alloc] initWithWidth:320 height:240];
  NSError *error;
  CVPixelBufferRef pixelBuffer = [converter copyPixelBufferFromImageData:jpegData error:&error];
  XCTAssertTrue(pixelBuffer != NULL, @"%@", error);
  XCTAssertEqual(CVPixelBufferGetWidth(pixelBuffer), (size_t)320);
  XCTAssertEqual(CVPixelBufferGetHeight(pixelBuffer), (size_t)240);
  CVPixelBufferRelease(pixelBuffer);
}

@end
