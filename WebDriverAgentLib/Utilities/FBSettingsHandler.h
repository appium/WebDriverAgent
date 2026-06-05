/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@class FBCommandStatus;
@class FBSession;

NS_ASSUME_NONNULL_BEGIN

@interface FBSettingsHandler : NSObject

/**
 * Applies the given settings dictionary to FBConfiguration and the active session.
 *
 * @return nil on success, or an FBCommandStatus describing the validation error.
 */
+ (nullable FBCommandStatus *)applySettings:(nullable NSDictionary *)settings toSession:(FBSession *)session;

/**
 * Returns the current values for all known settings.
 */
+ (NSDictionary *)currentSettingsForSession:(FBSession *)session;

@end

NS_ASSUME_NONNULL_END
