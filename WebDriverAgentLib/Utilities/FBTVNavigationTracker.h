/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
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

NS_ASSUME_NONNULL_BEGIN

/**
 Define for testing: FBTVNavigationItem
 */
@interface FBTVNavigationItem : NSObject
@property (nonatomic, readonly) NSUInteger uid;
@property (nonatomic, readonly) NSMutableSet<NSNumber *>* directions;

+ (instancetype)itemWithUid:(NSUInteger) uid;
@end
// end for testing

@interface FBTVNavigationTracker : NSObject

/**
 Track the target element's point

 @param targetElement A target element which will track
 @return An instancce of FBTVNavigationTracker
 */
+ (instancetype)trackerWithTargetElement: (XCUIElement *) targetElement;

/**
 Determine the correct direction to move the focus to the tracked target
 element from the currently focused one

 @return FBTVDirection to move the focus to
 */
- (FBTVDirection)directionToFocusedElement;

/**
 Define for testing: horizontalDirectionWithItem, verticalDirectionWithItem
 */
- (FBTVDirection)horizontalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
- (FBTVDirection)verticalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
// end for testing

@end

NS_ASSUME_NONNULL_END

#endif
