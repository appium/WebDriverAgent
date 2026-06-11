/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIDevice (FBVoiceOver)

/**
 Whether VoiceOver control APIs are available in the current OS runtime.

 @return YES if the VoiceOver service is exposed by XCUIDevice
 */
- (BOOL)fb_isVoiceOverServiceAvailable;

/**
 Enable VoiceOver. Only works since iOS 27 runtime.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if VoiceOver has been successfully enabled
 */
- (BOOL)fb_enableVoiceOver:(NSError **)error;

/**
 Disable VoiceOver. Only works since iOS 27 runtime.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if VoiceOver has been successfully disabled
 */
- (BOOL)fb_disableVoiceOver:(NSError **)error;

/**
 Whether VoiceOver is currently enabled. Only works since iOS 27 runtime.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if VoiceOver is enabled
 */
- (BOOL)fb_isVoiceOverEnabled:(NSError **)error;

/**
 Move VoiceOver focus and return speech for the newly focused element.
 Only works since iOS 27 runtime.

 @param direction One of: forward, backward, in (iOS only), out (iOS only)
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return The spoken utterance or nil in case of failure
 */
- (nullable NSString *)fb_voiceOverMove:(NSString *)direction error:(NSError **)error;

/**
 Return the speech for the currently focused element. Only works since iOS 27 runtime.

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return The spoken utterance or nil in case of failure
 */
- (nullable NSString *)fb_voiceOverCurrentSpeech:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
