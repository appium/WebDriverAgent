/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <WebDriverAgentLib/FBXCElementSnapshotWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBIsVisible)

/*! Whether or not the element is visible */
@property (atomic, readonly) BOOL fb_isVisible;

@end


@interface FBXCElementSnapshotWrapper (FBIsVisible)

/*! Whether a descendant already has a cached visible flag. Does not query AX. */
- (BOOL)fb_hasVisibleDescendants;

/*! Whether or not the element is visible */
@property (atomic, readonly) BOOL fb_isVisible;

@end

NS_ASSUME_NONNULL_END
