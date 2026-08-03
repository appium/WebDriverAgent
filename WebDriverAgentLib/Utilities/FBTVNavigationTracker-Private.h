/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import "FBXCElementSnapshot.h"

#if TARGET_OS_TV

@interface FBTVNavigationItem ()
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) NSMutableSet<NSNumber *>* directions;

+ (instancetype)itemWithUid:(NSString *) uid;
@end


@interface FBTVNavigationTracker ()

- (FBTVDirection)horizontalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
- (FBTVDirection)verticalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
- (FBTVDirection)directionWithItem:(FBTVNavigationItem *)item
                              delta:(CGFloat)delta
                  positiveDirection:(FBTVDirection)positiveDirection
                  negativeDirection:(FBTVDirection)negativeDirection;

// Exposed for testing: the pure direction-math core of `-pollFocusState:`,
// parameterized on the already-resolved focused element's snapshot so tests
// can supply a fake one instead of a live query result.
- (FBTVDirection)directionTowardsTargetFromFocusedElementSnapshot:(id<FBXCElementSnapshot>)focusedSnapshot;
@end

#endif
