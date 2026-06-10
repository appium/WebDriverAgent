/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import <XCTest/XCTest.h>
#import "FBElementCache.h"

@class XCSynthesizedEventRecord;

NS_ASSUME_NONNULL_BEGIN

@interface XCUIApplication (FBTouchAction)

/**
 Perform complex touch action in scope of the current application.
 
 @param actions Array of dictionaries, whose format is described in W3C spec (https://github.com/jlipps/simple-wd-spec#perform-actions)
 @param elementCache Cached elements mapping for the currrent application. The method assumes all elements are already represented by their actual instances if nil value is set
 @param error If there is an error, upon return contains an NSError object that describes the problem
 @return YES If the touch action has been successfully performed without errors
 */
- (BOOL)fb_performW3CActions:(NSArray *)actions elementCache:(nullable FBElementCache *)elementCache error:(NSError * _Nullable*)error;

/**
 Validates a flat /mobilerun/actions array and builds a synthesized event record from it.
 Items are grouped by their optional integer 'pointerId' (default 0) into concurrent
 touch paths. Bypasses the W3C synthesizer and the element cache. Malformed input is a
 client error: the method returns nil and populates error.

 @param items array of {type,x,y,duration,button,pointerId} dictionaries. 'type' is one
        of pointerDown, pointerMove, pointerUp, pause. 'duration' is in milliseconds.
 @param error populated when the array is empty/non-array or an item is malformed.
 @return the event record, or nil if the input is invalid.
 */
- (nullable XCSynthesizedEventRecord *)fb_mobilerunEventRecordFromActions:(NSArray *)items error:(NSError * _Nullable*)error;

/**
 Convenience: builds the record via -fb_mobilerunEventRecordFromActions:error: and
 dispatches it. Skips the post-gesture stability wait.

 @param items array of action item dictionaries (see -fb_mobilerunEventRecordFromActions:error:).
 @param error populated on invalid input or synthesis failure.
 @return YES if the event was dispatched, otherwise NO.
 */
- (BOOL)fb_performMobilerunActions:(NSArray *)items error:(NSError * _Nullable*)error;

/**
 Dispatches a synthesized event record through the XCTest daemon. A failure here is a
 runtime/synthesis error rather than a client input error.

 @param event the synthesized event record to dispatch.
 @param error populated on a synthesis failure.
 @return YES if the event was dispatched, otherwise NO.
 */
- (BOOL)fb_synthesizeEvent:(XCSynthesizedEventRecord *)event error:(NSError * _Nullable*)error;

@end

NS_ASSUME_NONNULL_END
