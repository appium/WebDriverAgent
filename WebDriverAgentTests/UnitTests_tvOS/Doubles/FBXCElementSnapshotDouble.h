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
 Fake `id<FBXCElementSnapshot>` tree node. Deliberately does NOT declare
 formal conformance to the (large, mostly-unrelated) `FBXCElementSnapshot`
 protocol - it only implements the selectors
 `FBTVNavigationTracker`'s `-pollFocusStateWithApplicationSnapshot:direction:`
 actually reads: `frame`, `hasFocus`, `accessibilityElement` and
 `enumerateDescendantsUsingBlock:`. Cast to `id<FBXCElementSnapshot>` at the
 call site. Lets tests build a fake application snapshot tree without a live
 app/device.
 */
@interface FBXCElementSnapshotDouble : NSObject

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) BOOL hasFocus;
@property (nonatomic, copy) NSArray<FBXCElementSnapshotDouble *> *children;
@property (nonatomic, strong, nullable) FBXCAccessibilityElementDouble *accessibilityElement;

/**
 @param elementId Fake AX element id. Two snapshots built with the same
   elementId report the same `wdUID`; use `+wdUIDForElementId:` to compute
   the matching uid for an `XCUIElementDouble` target.
 @param frame The snapshot's frame
 @param hasFocus Whether this node should report `hasFocus == YES`
 @return A leaf snapshot double with no children
 */
+ (instancetype)snapshotWithElementId:(unsigned long long)elementId
                                 frame:(CGRect)frame
                              hasFocus:(BOOL)hasFocus;

/**
 @param elementId Fake AX element id, as passed to `+snapshotWithElementId:frame:hasFocus:`
 @return The `wdUID` a snapshot double built with that element id would report
 */
+ (NSString *)wdUIDForElementId:(unsigned long long)elementId;

- (void)enumerateDescendantsUsingBlock:(void (^)(id snapshot))block;

@end

NS_ASSUME_NONNULL_END
