/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBScreenshot : NSObject

/**
 Returns YES if the current OS SDK supports advanced screenshoting APIs (added since Xcode SDK 10)
 */
+ (BOOL)isNewScreenshotAPISupported;

/**
 Retrieves non-scaled screenshot of the whole screen

 @param quality The number in range 0-2, where 2 (JPG) is the lowest and 0 (PNG) is the highest quality.
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return Device screenshot as PNG- or JPG-encoded data or nil in case of failure
 */
+ (nullable NSData *)takeInOriginalResolutionWithQuality:(NSUInteger)quality
                                                   error:(NSError **)error;

/**
 Retrieves non-scaled screenshot of the particular screen rectangle

 @param quality The number in range 0-2, where 2 (JPG) is the lowest and 0 (PNG) is the highest quality.
 @param rect The bounding rectange for the screenshot. The value is expected be non-scaled one.
             CGRectNull could be used to take a screenshot of the full screen.
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return Device screenshot as PNG- or JPG-encoded data or nil in case of failure
 */
+ (nullable NSData *)takeInOriginalResolutionWithQuality:(NSUInteger)quality
                                                    rect:(CGRect)rect
                                                   error:(NSError **)error;

/**
 Retrieves non-scaled screenshot of the whole screen

 @param screenID The screen identifier to take the screenshot from
 @param compressionQuality Normalized screenshot quality value in range 0..1, where 1 is the best quality
 @param uti kUTType... constant, which defines the type of the returned screenshot image
 @param timeout how much time to allow for the screenshot to be taken
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return Device screenshot as PNG- or JPG-encoded data or nil in case of failure
 */
+ (nullable NSData *)takeInOriginalResolutionWithScreenID:(unsigned int)screenID
                                       compressionQuality:(CGFloat)compressionQuality
                                                      uti:(NSString *)uti
                                                  timeout:(NSTimeInterval)timeout
                                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
