/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <XCTest/XCUIElement.h>

#if TARGET_OS_TV

/**
 Defines directions to move focuse to.
 */
typedef NS_ENUM(NSUInteger, FBTVDirection) {
  FBTVDirectionUp     = 0,
  FBTVDirectionDown   = 1,
  FBTVDirectionLeft   = 2,
  FBTVDirectionRight  = 3,
  FBTVDirectionNone   = 4
};

/**
 Represents where the tracked target element currently stands with respect
 to keyboard/remote focus, as of the last `-pollFocusState:` call.
 */
typedef NS_ENUM(NSUInteger, FBTVFocusState) {
  // The target element currently has focus
  FBTVFocusStateFocused,
  // The target element could not be located in the accessibility tree anymore
  FBTVFocusStateGone,
  // The target element exists, but does not have focus yet
  FBTVFocusStatePending,
};

NS_ASSUME_NONNULL_BEGIN

@interface FBTVNavigationItem : NSObject
@end

@interface FBTVNavigationTracker : NSObject

/**
 Track the target element's point

 @param targetElement A target element which will track
 @return An instancce of FBTVNavigationTracker
 */
+ (instancetype)trackerWithTargetElement: (XCUIElement *) targetElement;

/**
 Determines whether the tracked target element currently has focus, whether
 it still exists, and - if neither - which direction the focus should move
 to get closer to it. Each of these is resolved with the cheapest available
 accessibility round trip for what it's checking: `hasFocus`/`exists` are
 single already-known-element checks, and the currently focused element (if
 any) is found via a targeted `hasFocus == true` query rather than a whole-app
 snapshot walk, whose cost scales with total app size/depth instead of with
 the (typically 0-1) number of matches.

 @param direction Always reset to `FBTVDirectionNone` first, then set to the
   suggested direction to move the focus to when the return value is
   `FBTVFocusStatePending`. It is left as `FBTVDirectionNone` when the return
   value is `FBTVFocusStateFocused`/`FBTVFocusStateGone`, or when the
   currently focused element could not be determined yet - in the latter
   case the caller should just retry on the next iteration.
 @return The current focus state of the tracked target element
 */
- (FBTVFocusState)pollFocusState:(FBTVDirection *)direction;

@end

NS_ASSUME_NONNULL_END

#endif
