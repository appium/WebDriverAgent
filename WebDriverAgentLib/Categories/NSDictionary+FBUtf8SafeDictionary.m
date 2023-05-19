/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "NSDictionary+FBUtf8SafeDictionary.h"

const unichar REPLACER = 0xfffd;

@implementation NSString (FBUtf8SafeString)

- (instancetype)fb_utf8SafeStringWithReplacement:(unichar)replacement
{
  if ([self canBeConvertedToEncoding:NSUTF8StringEncoding]) {
    return self;
  }

  NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
  NSString *convertedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSMutableString *result = [NSMutableString string];
  NSString *replacementStr = [NSString stringWithCharacters:&replacement length:1];
  NSUInteger originalIdx = 0;
  NSUInteger convertedIdx = 0;
  while (originalIdx < [self length] && convertedIdx < [convertedString length]) {
    unichar originalChar = [self characterAtIndex:originalIdx];
    unichar convertedChar = [convertedString characterAtIndex:convertedIdx];

    if (originalChar == convertedChar) {
      [result appendString:[NSString stringWithCharacters:&originalChar length:1]];
      originalIdx++;
      convertedIdx++;
      continue;
    }

    while (originalChar != convertedChar && originalIdx < [self length]) {
      [result appendString:replacementStr];
      originalChar = [self characterAtIndex:++originalIdx];
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
