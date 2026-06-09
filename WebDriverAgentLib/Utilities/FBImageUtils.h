/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/*! Returns YES if the data contains a PNG image */
BOOL FBIsPngImage(NSData *imageData);

/*! Converts the given image data to a PNG representation if necessary */
NSData *_Nullable FBToPngData(NSData *imageData);

/*! Returns YES if the data contains a JPG image */
BOOL FBIsJpegImage(NSData *imageData);

/*! Converts the given image data to a JPG representation if necessary */
NSData *_Nullable FBToJpegData(NSData *imageData, CGFloat compressionQuality);

/*!
 Decodes the given encoded image into a CGImage with its EXIF orientation baked into the pixels
 (i.e. upright). This is required before feeding screenshots into a raw video encoder, which has
 no way to carry the orientation metadata that XCTest stores for landscape screenshots.
 The caller owns the returned image and must call CGImageRelease.
 */
CGImageRef _Nullable FBCreateOrientedCGImageFromData(NSData *imageData) CF_RETURNS_RETAINED;

NS_ASSUME_NONNULL_END
