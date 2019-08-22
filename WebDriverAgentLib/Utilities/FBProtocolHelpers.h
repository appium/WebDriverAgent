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
 Inserts element uuid into the response dictionary

 @param dst The target dictionary. It is NOT mutated
 @param element Either element identifier or element object itself
 @returns The changed dictionary
 */
NSDictionary *FBInsertElement(NSDictionary *dst, id element);

/**
 Extracts element uuid from dictionary

 @param src The source dictionary
 @returns The resulting element or nil if no element keys are found
 */
id _Nullable FBExtractElement(NSDictionary *src);

/**
 Cleanup items having element keys from the dictionary
 
 @param src The source dictionary
 @returns The resulting dictionary
 */
NSDictionary *FBCleanupElements(NSDictionary *src);

/**
 Parses key/value pairs of valid W3C capabilities

 @param caps The source capabilitites dictionary
 @param error Is set if there was an error while parsing the source capabilities
 @returns Parsed capabilitites mapping or nil in case of failure
 */
NSDictionary<NSString *, id> *_Nullable FBParseCapabilities(NSDictionary<NSString *, id> *caps, NSError **error);

NS_ASSUME_NONNULL_END
