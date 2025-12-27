/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <WebDriverAgentLib/FBXCElementSnapshotWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBCustomActions)

/*! Custom accessibility actions as a string – may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSString *fb_customActions;

@end

@interface FBXCElementSnapshotWrapper (FBCustomActions)

/*! Custom accessibility actions as a string – may be nil if the element does not have this attribute */
@property (nonatomic, readonly, nullable) NSString *fb_customActions;

@end

NS_ASSUME_NONNULL_END
