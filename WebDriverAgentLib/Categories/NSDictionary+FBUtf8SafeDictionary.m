/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "NSDictionary+FBUtf8SafeDictionary.h"

const unichar REPLACER = 0xfffd;

@implementation NSString (FBUtf8SafeString)

- (instancetype)fb_utf8SafeStringWithReplacement:(unichar)replacement
{
  // -canBeConvertedToEncoding: and -dataUsingEncoding:allowLossyConversion:
  // both misreport strings containing unpaired UTF-16 surrogates, so the
  // code units are validated manually instead of relying on them.
  NSUInteger length = self.length;
  NSMutableString *result = [NSMutableString stringWithCapacity:length];
  NSString *replacementStr = [NSString stringWithCharacters:&replacement length:1];
  NSUInteger idx = 0;
  while (idx < length) {
    unichar c = [self characterAtIndex:idx];
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (idx + 1 < length) {
        unichar next = [self characterAtIndex:idx + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          [result appendString:[self substringWithRange:NSMakeRange(idx, 2)]];
          idx += 2;
          continue;
        }
      }
      [result appendString:replacementStr];
      idx += 1;
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      [result appendString:replacementStr];
      idx += 1;
    } else {
      [result appendString:[self substringWithRange:NSMakeRange(idx, 1)]];
      idx += 1;
    }
  }
  return result.copy;
}

@end

@implementation NSArray (FBUtf8SafeArray)

- (instancetype)fb_utf8SafeArray
{
  NSMutableArray *result = [NSMutableArray array];
  for (id item in self) {
    if ([item isKindOfClass:NSString.class]) {
      [result addObject:[(NSString *)item fb_utf8SafeStringWithReplacement:REPLACER]];
    } else if ([item isKindOfClass:NSDictionary.class]) {
      [result addObject:[(NSDictionary *)item fb_utf8SafeDictionary]];
    } else if ([item isKindOfClass:NSArray.class]) {
      [result addObject:[(NSArray *)item fb_utf8SafeArray]];
    } else {
      [result addObject:item];
    }
  }
  return result.copy;
}

@end

@implementation NSDictionary (FBUtf8SafeDictionary)

- (instancetype)fb_utf8SafeDictionary
{
  NSMutableDictionary *result = [self mutableCopy];
  for (id key in self) {
    id value = result[key];
    if ([value isKindOfClass:NSString.class]) {
      result[key] = [(NSString *)value fb_utf8SafeStringWithReplacement:REPLACER];
    } else if ([value isKindOfClass:NSArray.class]) {
      result[key] = [(NSArray *)value fb_utf8SafeArray];
    } else if ([value isKindOfClass:NSDictionary.class]) {
      result[key] = [(NSDictionary *)value fb_utf8SafeDictionary];
    }
  }
  return result.copy;
}

@end
