/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCElementSnapshotWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBVisibleFrame)

/**
 Returns the snapshot visibleFrame with a fallback to direct attribute retrieval from FBXCAXClient in case of a snapshot fault (nil visibleFrame)

 @return the snapshot visibleFrame
 */
- (CGRect)fb_visibleFrame;

@end

@interface FBXCElementSnapshotWrapper (FBVisibleFrame)

/**
 Returns the snapshot visibleFrame with a fallback to direct attribute retrieval from FBXCAXClient in case of a snapshot fault (nil visibleFrame)

 @return the snapshot visibleFrame
 */
- (CGRect)fb_visibleFrame;

@end

NS_ASSUME_NONNULL_END
