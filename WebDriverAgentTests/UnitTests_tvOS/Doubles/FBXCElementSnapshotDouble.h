/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBXCAccessibilityElementDouble.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Fake `id<FBXCElementSnapshot>` leaf node. Deliberately does NOT declare
 formal conformance to the (large, mostly-unrelated) `FBXCElementSnapshot`
 protocol - it only implements the selectors
 `FBTVNavigationTracker`'s `-directionTowardsTargetFromFocusedElementSnapshot:`
 actually reads: `frame`, `hasFocus` and `accessibilityElement` (the latter
 indirectly, via `FBXCElementSnapshotWrapper.wdUID`). Cast to
 `id<FBXCElementSnapshot>` at the call site. Lets tests supply a fake focused
 element snapshot without a live app/device.
 */
@interface FBXCElementSnapshotDouble : NSObject

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) BOOL hasFocus;
@property (nonatomic, strong, nullable) FBXCAccessibilityElementDouble *accessibilityElement;

/**
 @param elementId Fake AX element id, used to derive a distinct `wdUID`
 @param frame The snapshot's frame
 @param hasFocus Whether this node should report `hasFocus == YES`
 @return A snapshot double
 */
+ (instancetype)snapshotWithElementId:(unsigned long long)elementId
                                 frame:(CGRect)frame
                              hasFocus:(BOOL)hasFocus;

@end

NS_ASSUME_NONNULL_END
