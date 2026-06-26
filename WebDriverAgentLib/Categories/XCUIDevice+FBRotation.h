/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

#if !TARGET_OS_TV
@interface XCUIDevice (FBRotation)

/**
 Sets requested device interface orientation.

 @param orientation The interface orientation.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_setDeviceInterfaceOrientation:(UIDeviceOrientation)orientation;

/**
 Sets the devices orientation to the rotation passed.
 
 @param rotationObj The rotation defining the devices orientation.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_setDeviceRotation:(NSDictionary *)rotationObj;

/*! The UIDeviceOrientation to rotation mappings */
@property (strong, nonatomic, readonly) NSDictionary *fb_rotationMapping;

/**
 The current physical device orientation as the raw UIDeviceOrientation name string,
 e.g. UIDeviceOrientationPortrait, UIDeviceOrientationLandscapeLeft,
 UIDeviceOrientationFaceUp. Returns UIDeviceOrientationUnknown if the orientation
 cannot be determined.
 */
@property (copy, nonatomic, readonly) NSString *fb_deviceOrientation;

@end
#endif

NS_ASSUME_NONNULL_END
