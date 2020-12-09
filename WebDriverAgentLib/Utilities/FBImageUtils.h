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

/*! Returns YES if the data contains a PNG image */
BOOL FBIsPngImage(NSData *imageData);

/*! Converts the given image data to a PNG representation if necessary */
NSData *_Nullable FBToPngData(NSData *imageData);

#if TARGET_OS_TV
NSData *_Nullable FBAdjustScreenshotOrientationForApplication(NSData *screenshotData);
#else
/*! Fixes the screenshot orientation if necessary to match current screen orientation */
NSData *_Nullable FBAdjustScreenshotOrientationForApplication(NSData *screenshotData, UIInterfaceOrientation orientation);
#endif

NS_ASSUME_NONNULL_END
