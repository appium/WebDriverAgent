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
 Presses at startCoordinate, drags to endCoordinate and holds there, producing the same touch event
 path as -[XCUICoordinate pressForDuration:thenDragToCoordinate:withVelocity:thenHoldForDuration:].

 Unlike that XCTest method, both screen points are resolved exactly once, up front, and validated
 before anything is sent; the resulting event is then synthesized directly, without XCTest's
 dispatch-time re-snapshot and quiescence wait of the application. XCTest resolves the points
 inside that dispatch, so an application that is busy (e.g. right after an app switch) makes it
 hang and then assert on an infinite point instead of failing cleanly.
 See https://github.com/appium/WebDriverAgent/issues/1056

 @param startCoordinate The coordinate to press at
 @param pressDuration How long to hold still at startCoordinate before dragging, in seconds (>= 0)
 @param endCoordinate The coordinate to drag to
 @param velocity Drag velocity in points per second, or one of the XCUIGestureVelocity constants
 @param holdDuration How long to hold still at endCoordinate before lifting, in seconds (>= 0)
 @param error If there is an error, upon return contains an NSError object that describes the problem
 @return YES if the gesture has been successfully performed
 @throws FBInvalidArgumentException if a duration or the velocity is out of range
 */
- (BOOL)fb_pressAtCoordinate:(XCUICoordinate *)startCoordinate
                 forDuration:(NSTimeInterval)pressDuration
        thenDragToCoordinate:(XCUICoordinate *)endCoordinate
                withVelocity:(XCUIGestureVelocity)velocity
         thenHoldForDuration:(NSTimeInterval)holdDuration
                       error:(NSError * _Nullable*)error;

#if !TARGET_OS_TV && !TARGET_OS_WATCH
/**
 Builds the synthesized event used by
 -fb_pressAtCoordinate:forDuration:thenDragToCoordinate:withVelocity:thenHoldForDuration:error:
 from already resolved screen points. Exposed for testing.

 @param startPoint The screen point to press at
 @param pressDuration How long to hold still at startPoint before dragging, in seconds
 @param endPoint The screen point to drag to
 @param pointsPerSecond The drag speed
 @param holdDuration How long to hold still at endPoint before lifting, in seconds
 @param displayID The display to send the gesture to (0 is the main display)
 @param interfaceOrientation The interface orientation the points are expressed in
 @return The event record, ready to be synthesized
 */
+ (XCSynthesizedEventRecord *)fb_pressDragEventFromPoint:(CGPoint)startPoint
                                             forDuration:(NSTimeInterval)pressDuration
                                                 toPoint:(CGPoint)endPoint
                                         pointsPerSecond:(CGFloat)pointsPerSecond
                                     thenHoldForDuration:(NSTimeInterval)holdDuration
                                               displayID:(long long)displayID
                                    interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
#endif

@end

NS_ASSUME_NONNULL_END
