/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// See FBConfiguration.h for more details on the meaning of each setting

extern NSString* const USE_COMPACT_RESPONSES;
extern NSString* const ELEMENT_RESPONSE_ATTRIBUTES;
extern NSString* const MJPEG_SERVER_SCREENSHOT_QUALITY;
extern NSString* const MJPEG_SERVER_FRAMERATE;
extern NSString* const MJPEG_SCALING_FACTOR;
extern NSString* const SCREENSHOT_QUALITY;
extern NSString* const KEYBOARD_AUTOCORRECTION;
extern NSString* const KEYBOARD_PREDICTION;
// This setting is deprecated. Please use CUSTOM_SNAPSHOT_TIMEOUT instead
extern NSString* const SNAPSHOT_TIMEOUT;
extern NSString* const CUSTOM_SNAPSHOT_TIMEOUT;
extern NSString* const SNAPSHOT_MAX_DEPTH;
extern NSString* const USE_FIRST_MATCH;
extern NSString* const BOUND_ELEMENTS_BY_INDEX;
extern NSString* const REDUCE_MOTION;
extern NSString* const DEFAULT_ACTIVE_APPLICATION;
extern NSString* const ACTIVE_APP_DETECTION_POINT;
extern NSString* const INCLUDE_NON_MODAL_ELEMENTS;
extern NSString* const DEFAULT_ALERT_ACTION;
extern NSString* const ACCEPT_ALERT_BUTTON_SELECTOR;
extern NSString* const DISMISS_ALERT_BUTTON_SELECTOR;
extern NSString* const SCREENSHOT_ORIENTATION;
extern NSString* const WAIT_FOR_IDLE_TIMEOUT;
extern NSString* const ANIMATION_COOL_OFF_TIMEOUT;


NS_ASSUME_NONNULL_END
