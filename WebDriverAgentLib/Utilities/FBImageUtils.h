/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

/*! Returns YES if the data contains a JPEG image */
BOOL FBIsJpegImage(NSData *imageData);

/*! Returns YES if the data contains a PNG image */
BOOL FBIsPngImage(NSData *imageData);

#if TARGET_OS_TV
NSData *FBAdjustScreenshotOrientationForApplication(NSData *screenshotData);
#else
/*! Fixes the screenshot orientation if necessary to match current screen orientation */
NSData *FBAdjustScreenshotOrientationForApplication(NSData *screenshotData, UIInterfaceOrientation orientation);
#endif
