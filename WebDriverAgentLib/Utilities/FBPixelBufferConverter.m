/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBPixelBufferConverter.h"

#import <ImageIO/ImageIO.h>

NSErrorDomain const FBPixelBufferConverterErrorDomain = @"com.facebook.WebDriverAgent.FBPixelBufferConverter";
static CFStringRef const FBPixelBufferBitmapContextAttachmentKey = CFSTR("com.facebook.WebDriverAgent.FBPixelBufferConverter.BitmapContext");

static size_t FBEvenDimension(size_t value)
{
  if (value < 2) {
    return 2;
  }
  return value - (value % 2);
}

@interface FBPixelBufferConverter ()
@property (nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic) CGColorSpaceRef colorSpace;

- (nullable CGContextRef)copyBitmapContextForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                   error:(NSError **)error CF_RETURNS_RETAINED;
@end

@implementation FBPixelBufferConverter

- (instancetype)initWithWidth:(size_t)width height:(size_t)height
{
  if ((self = [super init])) {
    _width = FBEvenDimension(width);
    _height = FBEvenDimension(height);
    _colorSpace = CGColorSpaceCreateDeviceRGB();

    NSDictionary *poolAttributes = @{
      (id)kCVPixelBufferPoolMinimumBufferCountKey: @(3),
    };
    NSDictionary *pixelBufferAttributes = @{
      (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
      (id)kCVPixelBufferWidthKey: @(_width),
      (id)kCVPixelBufferHeightKey: @(_height),
      (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
      (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
      (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };
    CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                              (__bridge CFDictionaryRef)poolAttributes,
                                              (__bridge CFDictionaryRef)pixelBufferAttributes,
                                              &_pixelBufferPool);
    if (status != kCVReturnSuccess) {
      _pixelBufferPool = NULL;
    }
  }
  return self;
}

- (nullable CVPixelBufferRef)copyPixelBufferFromImageData:(NSData *)imageData
                                                   error:(NSError **)error
{
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
  if (NULL == source) {
    if (error) {
      *error = [NSError errorWithDomain:FBPixelBufferConverterErrorDomain
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey: @"Cannot create an image source from the given data"}];
    }
    return NULL;
  }
  CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
  CFRelease(source);
  if (NULL == image) {
    if (error) {
      *error = [NSError errorWithDomain:FBPixelBufferConverterErrorDomain
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey: @"Cannot decode the given image data"}];
    }
    return NULL;
  }
  CVPixelBufferRef result = [self copyPixelBufferFromCGImage:image error:error];
  CGImageRelease(image);
  return result;
}

- (nullable CVPixelBufferRef)copyPixelBufferFromCGImage:(CGImageRef)image
                                                 error:(NSError **)error
{
  if (NULL == self.pixelBufferPool) {
    if (error) {
      *error = [NSError errorWithDomain:FBPixelBufferConverterErrorDomain
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey: @"The pixel buffer pool has not been initialized"}];
    }
    return NULL;
  }

  CVPixelBufferRef pixelBuffer = NULL;
  CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self.pixelBufferPool, &pixelBuffer);
  if (status != kCVReturnSuccess || NULL == pixelBuffer) {
    if (error) {
      *error = [NSError errorWithDomain:FBPixelBufferConverterErrorDomain
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot allocate a pixel buffer (status %d)", status]}];
    }
    return NULL;
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  CGContextRef context = [self copyBitmapContextForPixelBuffer:pixelBuffer
                                                         error:error];
  if (NULL == context) {
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
    return NULL;
  }

  // Scale to fit while preserving the aspect ratio and center the result.
  CGFloat imageWidth = (CGFloat)CGImageGetWidth(image);
  CGFloat imageHeight = (CGFloat)CGImageGetHeight(image);
  if (imageWidth > 0 && imageHeight > 0) {
    CGFloat scale = MIN((CGFloat)self.width / imageWidth, (CGFloat)self.height / imageHeight);
    CGFloat targetWidth = imageWidth * scale;
    CGFloat targetHeight = imageHeight * scale;
    CGFloat originX = ((CGFloat)self.width - targetWidth) / 2.0;
    CGFloat originY = ((CGFloat)self.height - targetHeight) / 2.0;
    BOOL needsPadding = originX > 0.5
      || originY > 0.5
      || targetWidth < (CGFloat)self.width - 0.5
      || targetHeight < (CGFloat)self.height - 0.5;
    if (needsPadding) {
      // Fill only when the frame needs letterbox/pillarbox padding; a full-frame draw overwrites
      // every pixel and does not need the clear.
      CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
      CGContextFillRect(context, CGRectMake(0, 0, self.width, self.height));
    }
    CGContextDrawImage(context, CGRectMake(originX, originY, targetWidth, targetHeight), image);
  }

  CGContextRelease(context);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  return pixelBuffer;
}

- (nullable CGContextRef)copyBitmapContextForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                   error:(NSError **)error
{
  CGContextRef cachedContext = (CGContextRef)CVBufferCopyAttachment(pixelBuffer,
                                                                    FBPixelBufferBitmapContextAttachmentKey,
                                                                    NULL);
  if (NULL != cachedContext) {
    return cachedContext;
  }

  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
  CGContextRef context = CGBitmapContextCreate(baseAddress,
                                               self.width,
                                               self.height,
                                               8,
                                               CVPixelBufferGetBytesPerRow(pixelBuffer),
                                               self.colorSpace,
                                               kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
  if (NULL == context) {
    if (error) {
      *error = [NSError errorWithDomain:FBPixelBufferConverterErrorDomain
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey: @"Cannot create a bitmap context for the pixel buffer"}];
    }
    return NULL;
  }

  CVBufferSetAttachment(pixelBuffer,
                        FBPixelBufferBitmapContextAttachmentKey,
                        context,
                        kCVAttachmentMode_ShouldNotPropagate);
  return context;
}

- (void)dealloc
{
  if (NULL != _pixelBufferPool) {
    CVPixelBufferPoolRelease(_pixelBufferPool);
    _pixelBufferPool = NULL;
  }
  if (NULL != _colorSpace) {
    CGColorSpaceRelease(_colorSpace);
    _colorSpace = NULL;
  }
}

@end
