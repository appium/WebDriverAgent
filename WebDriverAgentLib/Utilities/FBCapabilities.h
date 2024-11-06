/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

/** Whether to use alternative elements visivility detection method */
extern NSString* const FB_CAP_USE_TEST_MANAGER_FOR_VISIBLITY_DETECTION;
/** Set the maximum amount of characters that could be typed within a minute (60 by default) */
extern NSString* const FB_CAP_MAX_TYPING_FREQUENCY;
/** this setting was needed for some legacy stuff */
extern NSString* const FB_CAP_USE_SINGLETON_TEST_MANAGER;
/** Whether to disable screneshots that XCTest automaticallly creates after each step */
extern NSString* const FB_CAP_DISABLE_AUTOMATIC_SCREENSHOTS;
/** Whether to terminate the application under test after the session ends */
extern NSString* const FB_CAP_SHOULD_TERMINATE_APP;
/** The maximum amount of seconds to wait for the event loop to become idle */
extern NSString* const FB_CAP_EVENT_LOOP_IDLE_DELAY_SEC;
/** Bundle identifier of the application to run the test for */
extern NSString* const FB_CAP_BUNDLE_ID;
/**
 Usually an URL used as initial link to run Mobile Safari, but could be any other deep link.
 This might also work together with `FB_CAP_BUNLDE_ID`, which tells XCTest to open
 the given deep link in the particular app.
 Only works since iOS 16.4
 */
extern NSString* const FB_CAP_INITIAL_URL;
/** Whether to enforrce (re)start of the application under test on session startup */
extern NSString* const FB_CAP_FORCE_APP_LAUNCH;
/** Whether to wait for quiescence before starting interaction with apps laucnhes in scope of the test session */
extern NSString* const FB_CAP_SHOULD_WAIT_FOR_QUIESCENCE;
/** Array of command line arguments to be passed to the application under test */
extern NSString* const FB_CAP_ARGUMENTS;
/** Dictionary of environment variables to be passed to the application under test */
extern NSString* const FB_CAP_ENVIRNOMENT;
/** Whether to use native XCTest caching strategy */
extern NSString* const FB_CAP_USE_NATIVE_CACHING_STRATEGY;
/** Whether to enforce software keyboard presence on simulator */
extern NSString* const FB_CAP_FORCE_SIMULATOR_SOFTWARE_KEYBOARD_PRESENCE;
/** Sets the application state change timeout for the initial app startup */
extern NSString* const FB_CAP_APP_LAUNCH_STATE_TIMEOUT_SEC;
