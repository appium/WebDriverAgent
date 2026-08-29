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
  NSMutableString *result = nil;
  NSString *replacementStr = nil;
  NSUInteger copiedIdx = 0;
  NSUInteger idx = 0;
  while (idx < length) {
    unichar c = [self characterAtIndex:idx];
    if (c >= 0xD800 && c <= 0xDBFF && idx + 1 < length) {
      unichar next = [self characterAtIndex:idx + 1];
      if (next >= 0xDC00 && next <= 0xDFFF) {
        idx += 2;
        continue;
      }
    }
    if (c < 0xD800 || c > 0xDFFF) {
      idx += 1;
      continue;
    }
    // Unpaired surrogate found. Lazily allocate the result and copy over
    // the valid run preceding it, so strings without any are returned as-is.
    if (nil == result) {
      result = [NSMutableString stringWithCapacity:length];
      replacementStr = [NSString stringWithCharacters:&replacement length:1];
    }
    [result appendString:[self substringWithRange:NSMakeRange(copiedIdx, idx - copiedIdx)]];
    [result appendString:replacementStr];
    idx += 1;
    copiedIdx = idx;
  }
  if (nil == result) {
    return self;
  }
  [result appendString:[self substringWithRange:NSMakeRange(copiedIdx, length - copiedIdx)]];
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
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:self.count];
  for (id key in self) {
    id value = self[key];
    id safeValue = value;
    if ([value isKindOfClass:NSString.class]) {
      safeValue = [(NSString *)value fb_utf8SafeStringWithReplacement:REPLACER];
    } else if ([value isKindOfClass:NSArray.class]) {
      safeValue = [(NSArray *)value fb_utf8SafeArray];
    } else if ([value isKindOfClass:NSDictionary.class]) {
      safeValue = [(NSDictionary *)value fb_utf8SafeDictionary];
    }
    // Sanitized keys could theoretically collide (e.g. two distinct invalid
    // keys both reducing to the same replacement string); the later one
    // wins, same as any other NSDictionary literal with duplicate keys.
    id safeKey = [key isKindOfClass:NSString.class]
      ? [(NSString *)key fb_utf8SafeStringWithReplacement:REPLACER]
      : key;
    result[safeKey] = safeValue;
  }
  return result.copy;
}

@end
