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

@interface XCUIDevice (FBHelpers)

/**
 Matches or mismatches TouchID request

 @param shouldMatch determines if TouchID should be matched
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_fingerTouchShouldMatch:(BOOL)shouldMatch;

/**
 Forces the device under test to switch to the home screen

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_goToHomescreenWithError:(NSError **)error;

/**
 Checks if the screen is locked or not.
 
 @return YES if screen is locked
 */
- (BOOL)fb_isScreenLocked;

/**
 Forces the device under test to switch to the lock screen. An immediate return will happen if the device is already locked and an error is going to be thrown if the screen has not been locked after the timeout.
 
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_lockScreen:(NSError **)error;

/**
 Forces the device under test to unlock. An immediate return will happen if the device is already unlocked and an error is going to be thrown if the screen has not been unlocked after the timeout.
 
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation succeeds, otherwise NO.
 */
- (BOOL)fb_unlockScreen:(NSError **)error;

/**
 Returns screenshot
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return Device screenshot as PNG-encoded data or nil in case of failure
 */
- (nullable NSData *)fb_screenshotWithError:(NSError*__autoreleasing*)error;

/**
 Returns device current wifi ip4 address
 */
- (nullable NSString *)fb_wifiIPAddress;

/**
 Opens the particular url scheme using Siri voice recognition helpers.
 This will only work since XCode 8.3/iOS 10.3
 
 @param url The url scheme represented as a string, for example https://apple.com
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation was successful
 */
- (BOOL)fb_openUrl:(NSString *)url error:(NSError **)error;

/**
 Presses the corresponding hardware button on the device

 @param buttonName One of the supported button names: volumeUp (real devices only), volumeDown (real device only), home
 @return YES if the button has been pressed
 */
- (BOOL)fb_pressButton:(NSString *)buttonName error:(NSError **)error;

/**
 Activates Siri service voice recognition with the given text to parse

 @param text The actual string to parse
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES the command has been successfully executed by Siri voice recognition service
 */
- (BOOL)fb_activateSiriVoiceRecognitionWithText:(NSString *)text error:(NSError **)error;

/**
 Eumlated triggering of the given low-level IOHID device event. The constants for possible events are defined
 in https://unix.superglobalmegacorp.com/xnu/newsrc/iokit/IOKit/hidsystem/IOHIDUsageTables.h.html
 Popular constants:
 - kHIDPage_Consumer = 0x0C
 - kHIDUsage_Csmr_VolumeIncrement  = 0xE9 (Volume Up)
 - kHIDUsage_Csmr_VolumeDecrement  = 0xEA (Volume Down)
 - kHIDUsage_Csmr_Menu = 0x40 (Home)
 - kHIDUsage_Csmr_Power  = 0x30 (Power)
 - kHIDUsage_Csmr_Snapshot  = 0x65 (Power + Home)

 @param page The event page identifier
 @param usage The event usage indentifier (usages are defined per-page)
 @param duration The event duration in float seconds (XCTest uses 0.005 for a single press event)
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES the event has successfully been triggered
 */
- (BOOL)fb_performIOHIDEventWithPage:(unsigned int)page
                               usage:(unsigned int)usage
                            duration:(NSTimeInterval)duration
                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
