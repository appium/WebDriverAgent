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

@interface NSString (FBUtf8SafeString)

/**
 Converts the string, so it could be properly represented in UTF-8 encoding. All non-encodable characters are replaced with
 the given `replacement`

 @param replacement The character to use a a replacement for the lossy encoding
 @returns Either the same string or a string with non-encodable chars replaced
 */
- (instancetype)fb_utf8SafeStringWithReplacement:(unichar)replacement;

@end

@interface NSDictionary (FBUtf8SafeDictionary)

/**
 Converts the dictionary, so it could be properly represented in UTF-8 encoding. All non-encodable characters
 in string values are replaced with the Unocde question mark characters. Nested dictionaries and arrays are
 processed recursively.

 @returns Either the same dictionary or a dictionary with non-encodable chars in string values replaced
 */
- (instancetype)fb_utf8SafeDictionary;

@end

NS_ASSUME_NONNULL_END
