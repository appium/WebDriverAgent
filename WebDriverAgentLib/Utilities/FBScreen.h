/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBScreen : NSObject

/**
 Information about all displays available to the device
 */
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)screensWithError:(NSError **)error;

/**
 The display with the given identifier

 @param displayID The display identifier, as returned by screensWithError:
 @param error Set if the display is not available
 @return The matching display or nil
 */
+ (nullable XCUIScreen *)screenWithDisplayID:(long long)displayID error:(NSError **)error;

/**
 The display selected by the currentDisplayId setting, or the main display if the setting is not set

 @param error Set if the selected display is no longer available
 @return The selected display or nil
 */
+ (nullable XCUIScreen *)currentScreenWithError:(NSError **)error;

/**
 The identifier of the main device's display
 */
+ (long long)displayID;

/**
 The scale factor of the main device's screen
 */
+ (double)scale;

@end

NS_ASSUME_NONNULL_END
