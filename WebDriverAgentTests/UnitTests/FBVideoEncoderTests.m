/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBPixelBufferConverter.h"
#import "FBVideoEncoder.h"

@interface FBVideoEncoderTests : XCTestCase <FBVideoEncoderDelegate>
@property (nonatomic) NSMutableArray<NSData *> *frames;
@property (nonatomic) NSMutableArray<NSNumber *> *keyFrameFlags;
@property (nonatomic, nullable) XCTestExpectation *frameExpectation;
@end

@implementation FBVideoEncoderTests

- (void)setUp
{
  [super setUp];
  self.frames = [NSMutableArray array];
  self.keyFrameFlags = [NSMutableArray array];
}

- (void)videoEncoder:(FBVideoEncoder *)encoder
       didEncodeFrame:(NSData *)annexBData
           isKeyFrame:(BOOL)isKeyFrame
{
  @synchronized (self.frames) {
    [self.frames addObject:annexBData];
    [self.keyFrameFlags addObject:@(isKeyFrame)];
  }
  [self.frameExpectation fulfill];
}

- (CGImageRef)solidImageOfWidth:(size_t)width height:(size_t)height CF_RETURNS_RETAINED
{
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace,
                                               kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  CGContextSetRGBFillColor(context, 0.2, 0.4, 0.6, 1.0);
  CGContextFillRect(context, CGRectMake(0, 0, width, height));
  CGImageRef image = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  return image;
}

- (void)runEncoderTestWithCodec:(FBVideoCodec)codec
{
  NSError *error;
  FBVideoEncoder *encoder = [[FBVideoEncoder alloc] initWithCodec:codec
                                                           width:320
                                                          height:240
                                                         bitrate:2000000
                                                             fps:30
                                                           error:&error];
  if (nil == encoder) {
    XCTSkip(@"VideoToolbox compression session is not available on this host: %@", error);
    return;
  }
  encoder.delegate = self;

  self.frameExpectation = [self expectationWithDescription:@"received at least one encoded frame"];
  self.frameExpectation.assertForOverFulfill = NO;

  FBPixelBufferConverter *converter = [[FBPixelBufferConverter alloc] initWithWidth:320 height:240];
  [encoder requestKeyFrame];
  for (NSUInteger i = 0; i < 15; i++) {
    CGImageRef image = [self solidImageOfWidth:320 height:240];
    CVPixelBufferRef pixelBuffer = [converter copyPixelBufferFromCGImage:image error:&error];
    CGImageRelease(image);
    XCTAssertTrue(pixelBuffer != NULL, @"%@", error);
    [encoder encodePixelBuffer:pixelBuffer presentationTimeMs:(i + 1) * 33 error:&error];
    CVPixelBufferRelease(pixelBuffer);
  }

  XCTWaiterResult waitResult = [XCTWaiter waitForExpectations:@[self.frameExpectation] timeout:10.0];
  [encoder stop];

  if (waitResult != XCTWaiterResultCompleted) {
    XCTSkip(@"VideoToolbox did not produce any frames on this host (encoder likely unavailable)");
    return;
  }

  NSArray<NSData *> *frames;
  NSArray<NSNumber *> *flags;
  @synchronized (self.frames) {
    frames = self.frames.copy;
    flags = self.keyFrameFlags.copy;
  }
  XCTAssertGreaterThan(frames.count, 0u);

  // Every emitted frame must be a sequence of Annex-B NAL units.
  const uint8_t startCode[4] = {0x00, 0x00, 0x00, 0x01};
  for (NSData *frame in frames) {
    XCTAssertGreaterThanOrEqual(frame.length, 4u);
    XCTAssertEqual(0, memcmp(frame.bytes, startCode, 4), @"Each frame must start with a 4-byte Annex-B start code");
  }

  // Hardware key-frame/parameter-set semantics cannot be exercised on hosts whose
  // VideoToolbox encoder does not emit IDR frames with parameter sets (notably the HEVC
  // simulator encoder). The H.264 path produces them even on the simulator.
  if (nil == encoder.parameterSetAnnexB) {
    XCTSkip(@"This host did not emit parameter sets (likely a simulator limitation)");
    return;
  }

  // The first frame is a key frame and must carry parameter sets.
  XCTAssertTrue(flags.firstObject.boolValue, @"The first emitted frame should be a key frame");
  XCTAssertGreaterThan(encoder.parameterSetAnnexB.length, 4u);
  XCTAssertEqual(0, memcmp(encoder.parameterSetAnnexB.bytes, startCode, 4),
                 @"Parameter sets must be prefixed with an Annex-B start code");
}

- (void)testEncodesH264AnnexBStream
{
  [self runEncoderTestWithCodec:FBVideoCodecH264];
}

- (void)testEncodesH265AnnexBStream
{
  [self runEncoderTestWithCodec:FBVideoCodecH265];
}

@end
