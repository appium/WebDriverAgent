/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/FBElement.h>
#import <WebDriverAgentLib/XCUIElement.h>
#import <WebDriverAgentLib/FBXCElementSnapshotWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (WebDriverAttributes) <FBElement>

@end


@interface FBXCElementSnapshotWrapper (WebDriverAttributes) <FBElement>

/**
 Fetches wdName attribute value for the given snapshot instance

 @param snapshot snapshot instance
 @return wdName attribute value or nil
 */
+ (nullable NSString *)wdNameWithSnapshot:(id<FBXCElementSnapshot>)snapshot;

@end

NS_ASSUME_NONNULL_END
