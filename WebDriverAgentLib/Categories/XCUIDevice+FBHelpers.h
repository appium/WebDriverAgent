/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#if !TARGET_OS_TV
#import <CoreLocation/CoreLocation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FBUIInterfaceAppearance) {
  FBUIInterfaceAppearanceUnspecified,
  FBUIInterfaceAppearanceLight,
  FBUIInterfaceAppearanceDark
};

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
 Returns device's current wifi ip4 address
 */
- (nullable NSString *)fb_wifiIPAddress;

/**
 Opens the particular url scheme using the default application assigned to it.
 This API only works since XCode 14.3/iOS 16.4
 Older Xcode/iOS version try to use Siri fallback.
 
 @param url The url scheme represented as a string, for example https://apple.com
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation was successful
 */
- (BOOL)fb_openUrl:(NSString *)url error:(NSError **)error;

/**
 Opens the particular url scheme using the given application
 This API only works since XCode 14.3/iOS 16.4

 @param url The url scheme represented as a string, for example https://apple.com
 @param bundleId The bundle identifier of an application to use in order to open the given URL
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the operation was successful
 */
- (BOOL)fb_openUrl:(NSString *)url withApplication:(NSString *)bundleId error:(NSError **)error;

/**
 Presses the corresponding hardware button on the device with duration.

 @param buttonName One of the supported button names: volumeUp (real devices only), volumeDown (real device only), home
 @param duration Duration in seconds or nil.
                This argument works only on tvOS. When this argument is nil on tvOS,
                https://developer.apple.com/documentation/xctest/xcuiremote/1627476-pressbutton will be called.
                Others are https://developer.apple.com/documentation/xctest/xcuiremote/1627475-pressbutton.
                A single tap when this argument is `nil` is equal to when the duration is 0.005 seconds in XCTest.
                On iOS, this value will be ignored. It always calls https://developer.apple.com/documentation/xctest/xcuidevice/1619052-pressbutton
 @return YES if the button has been pressed
 */
- (BOOL)fb_pressButton:(NSString *)buttonName forDuration:(nullable NSNumber *)duration error:(NSError **)error;


/**
 Activates Siri service voice recognition with the given text to parse

 @param text The actual string to parse
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES the command has been successfully executed by Siri voice recognition service
 */
- (BOOL)fb_activateSiriVoiceRecognitionWithText:(NSString *)text error:(NSError **)error;

/**
 Emulated triggering of the given low-level IOHID device event. The constants for possible events are defined
 in https://unix.superglobalmegacorp.com/xnu/newsrc/iokit/IOKit/hidsystem/IOHIDUsageTables.h.html
 Popular constants:
 - kHIDPage_Consumer = 0x0C
 - kHIDUsage_Csmr_VolumeIncrement  = 0xE9 (Volume Up)
 - kHIDUsage_Csmr_VolumeDecrement  = 0xEA (Volume Down)
 - kHIDUsage_Csmr_Menu = 0x40 (Home)
 - kHIDUsage_Csmr_Power  = 0x30 (Power)
 - kHIDUsage_Csmr_Snapshot  = 0x65 (Power + Home)

 @param page The event page identifier
 @param usage The event usage identifier (usages are defined per-page)
 @param duration The event duration in float seconds (XCTest uses 0.005 for a single press event)
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES the event has successfully been triggered
 */
- (BOOL)fb_performIOHIDEventWithPage:(unsigned int)page
                               usage:(unsigned int)usage
                            duration:(NSTimeInterval)duration
                               error:(NSError **)error;

/**
 Allows to set device appearance

 @param appearance The desired appearance value
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the appearance has been successfully set
 */
- (BOOL)fb_setAppearance:(FBUIInterfaceAppearance)appearance error:(NSError **)error;

/**
 Get current appearance prefefence.

 @return 0 (automatic), 1 (light) or 2 (dark), or nil
 */
- (nullable NSNumber *)fb_getAppearance;

#if !TARGET_OS_TV
/**
 Allows to set a simulated geolocation coordinates.
 Only works since Xcode 14.3/iOS 16.4

 @param location The simlated location coordinates to set
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the simulated location has been successfully set
 */
- (BOOL)fb_setSimulatedLocation:(CLLocation *)location error:(NSError **)error;

/**
 Allows to get a simulated geolocation coordinates.
 Only works since Xcode 14.3/iOS 16.4

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return The current simulated location or nil in case of failure or if no location has previously been seet
 (the returned error will be nil in the latter case)
 */
- (nullable CLLocation *)fb_getSimulatedLocation:(NSError **)error;

/**
 Allows to clear a previosuly set simulated geolocation coordinates.
 Only works since Xcode 14.3/iOS 16.4

 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return YES if the simulated location has been successfully cleared
 */
- (BOOL)fb_clearSimulatedLocation:(NSError **)error;
#endif

@end

NS_ASSUME_NONNULL_END
