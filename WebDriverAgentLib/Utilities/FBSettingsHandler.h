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
 * JSON null values are normalized to nil. Nil is applied only for settings that
 * support clearing (e.g. alert action and selectors); other keys are skipped so
 * null does not get coerced to NO/0. Unknown keys are skipped.
 *
 * @return nil on success, or an FBCommandStatus describing the validation error.
 */
+ (nullable FBCommandStatus *)applySettings:(NSDictionary *)settings toSession:(FBSession *)session;

/**
 * Returns the current values for all known settings.
 */
+ (NSDictionary *)currentSettingsForSession:(FBSession *)session;

@end

NS_ASSUME_NONNULL_END
