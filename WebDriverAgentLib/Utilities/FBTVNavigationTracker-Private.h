/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#if TARGET_OS_TV

@interface FBTVNavigationItem ()
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) NSMutableSet<NSNumber *>* directions;

+ (instancetype)itemWithUid:(NSString *) uid;
@end


@interface FBTVNavigationTracker ()

- (FBTVDirection)horizontalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
- (FBTVDirection)verticalDirectionWithItem:(FBTVNavigationItem *)item andDelta:(CGFloat)delta;
@end

#endif
