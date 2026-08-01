/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Fake AX process id used by every `FBXCAccessibilityElementDouble`. Shared
 (rather than hard-coded separately) with `FBXCElementSnapshotDouble`'s
 `+wdUIDForElementId:`, which independently derives the same uid formula and
 must stay in sync with this value.
 */
extern const int FBXCAccessibilityElementDoubleProcessIdentifier;

/**
 Minimal fake of the private `id<FBXCAccessibilityElement>` handle every
 real snapshot carries, just enough for `FBElementUtils uidWithAccessibilityElement:`
 to derive a stable, distinct `wdUID` per fake element id.
 */
@interface FBXCAccessibilityElementDouble : NSObject

@property (nonatomic, readonly) id payload;
@property (nonatomic, readonly) int processIdentifier;

- (instancetype)initWithElementId:(unsigned long long)elementId;

@end

NS_ASSUME_NONNULL_END
