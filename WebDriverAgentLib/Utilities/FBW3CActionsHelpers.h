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
 * Extracts value property for a key action
 *
 * @param actionItem Action item dictionary
 * @param error Contains the acttual error in case of failure
 * @returns Either the extracted value or nil in case of failure
 */
NSString *_Nullable FBRequireValue(NSDictionary<NSString *, id> *actionItem, NSError **error);

/**
 * Extracts duration property for an action
 *
 * @param actionItem Action item dictionary
 * @param defaultValue The default duration value if it is not present. If nil then the error will be set
 * @param error Contains the acttual error in case of failure
 * @returns Either the extracted value or nil in case of failure
 */
NSNumber *_Nullable FBOptDuration(NSDictionary<NSString *, id> *actionItem, NSNumber *_Nullable defaultValue, NSError **error);

/**
 * Maps W3C meta modifier to XCUITest compatible-one
 * See https://w3c.github.io/webdriver/#keyboard-actions
 *
 * @param value key action value
 * @returns the mapped modifier value or the same input character
 * if no mapped value could be found for it.
 */
NSString * FBMapIfSpecialCharacter(NSString *value);

NS_ASSUME_NONNULL_END
