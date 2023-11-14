/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBImageProcessor.h"
#import "FBIntegrationTestCase.h"


@interface FBImageProcessorTests : FBIntegrationTestCase

@property (nonatomic) NSData *originalImage;
@property (nonatomic) CGSize originalSize;

@end

@implementation FBImageProcessorTests

- (void)setUp {
  XCUIApplication *app = [[XCUIApplication alloc] init];
  [app launch];
  XCUIScreenshot *screenshot = app.screenshot;
  self.originalImage = UIImageJPEGRepresentation(screenshot.image, 1.0);
  self.originalSize = [FBImageProcessorTests scaledSizeFromImage:screenshot.image];
}

- (void)testScaling {
  CGFloat halfScale = 0.5;
  CGSize expectedHalfScaleSize = [FBImageProcessorTests sizeFromSize:self.originalSize scalingFactor:0.5];
  [self scaleImageWithFactor:halfScale
                expectedSize:expectedHalfScaleSize];

  // 0 is the smalles scaling factor we accept
  CGFloat minScale = 0.0;
  CGSize expectedMinScaleSize = [FBImageProcessorTests sizeFromSize:self.originalSize scalingFactor:0.01];
  [self scaleImageWithFactor:minScale
                expectedSize:expectedMinScaleSize];

  // For scaling factors above 100 we don't perform any scaling and just return the unmodified image
  [self scaleImageWithFactor:1.0
                expectedSize:self.originalSize];
  [self scaleImageWithFactor:2.0
                expectedSize:self.originalSize];
}

- (void)scaleImageWithFactor:(CGFloat)scalingFactor expectedSize:(CGSize)excpectedSize {
  FBImageProcessor *scaler = [[FBImageProcessor alloc] init];

  id expScaled = [self expectationWithDescription:@"Receive scaled image"];

  [scaler submitImageData:self.originalImage
            scalingFactor:scalingFactor
        completionHandler:^(NSData *scaled) {
    UIImage *scaledImage = [UIImage imageWithData:scaled];
    CGSize scaledSize = [FBImageProcessorTests scaledSizeFromImage:scaledImage];
    
    XCTAssertEqualWithAccuracy(scaledSize.width, excpectedSize.width, 1.0);
    XCTAssertEqualWithAccuracy(scaledSize.height, excpectedSize.height, 1.0);
    
    [expScaled fulfill];
  }];

  [self waitForExpectations:@[expScaled]
                    timeout:0.5];

}

+ (CGSize)scaledSizeFromImage:(UIImage *)image {
  return CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
}

+ (CGSize)sizeFromSize:(CGSize)size scalingFactor:(CGFloat)scalingFactor {
  return CGSizeMake(round(size.width * scalingFactor), round(size.height * scalingFactor));
}

@end

