/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Launches apps without attaching them to an XCUITest or a WDA session, allowing them to remain open
 when WDA closes.
*/
@interface FBUnattachedAppLauncher : NSObject

/**
 Launch the app with the specified bundle ID. Return YES if successful, NO otherwise.
 */
+ (BOOL)launchAppWithBundleId:(NSString *)bundleId;

@end

NS_ASSUME_NONNULL_END
