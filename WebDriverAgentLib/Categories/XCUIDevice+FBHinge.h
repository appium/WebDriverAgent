/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIDevice (FBHinge)

/** Whether a hinge and the CoreMotion angle-reading APIs are available. */
- (BOOL)fb_supportsHingeAngleReading;

/**
 Whether a hinge and the IOKit APIs needed to attempt injection are available.
 This does not guarantee event acceptance, particularly on physical devices.
 */
- (BOOL)fb_canAttemptSimulatedHingeAngleInjection;

/**
 Reads the current hinge angle in degrees, including changes made outside WDA.
 Waits up to 5 seconds for a valid reading. Does not change the hinge angle.
 @return The angle, or nil with an error if unavailable or reading times out.
 */
- (nullable NSNumber *)fb_getSimulatedHingeAngle:(NSError **)error;

/**
 Sends a simulated hinge angle in degrees (0 = closed, 180 = fully open).
 This dispatches the event; the display transition completes asynchronously.
 Verified on the iPhone Duo simulator; physical-device behavior is unverified.
 Does not change currentDisplayId.
 */
- (BOOL)fb_setSimulatedHingeAngle:(double)angle error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
