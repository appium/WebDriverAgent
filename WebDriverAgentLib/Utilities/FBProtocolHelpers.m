/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBProtocolHelpers.h"

#import "FBErrorBuilder.h"
#import "FBLogger.h"

static NSString *const W3C_ELEMENT_KEY = @"element-6066-11e4-a52e-4f735466cecf";
static NSString *const JSONWP_ELEMENT_KEY = @"ELEMENT";

static NSString *const APPIUM_PREFIX = @"appium";
static NSString *const ALWAYS_MATCH_KEY = @"alwaysMatch";
static NSString *const FIRST_MATCH_KEY = @"firstMatch";


NSDictionary *FBInsertElement(NSDictionary *dst, id element)
{
  NSMutableDictionary *result = dst.mutableCopy;
  result[W3C_ELEMENT_KEY] = element;
  result[JSONWP_ELEMENT_KEY] = element;
  return result.copy;
}

id FBExtractElement(NSDictionary *src)
{
  for (NSString* key in src) {
    if ([key.lowercaseString isEqualToString:W3C_ELEMENT_KEY.lowercaseString]
        || [key.lowercaseString isEqualToString:JSONWP_ELEMENT_KEY.lowercaseString]) {
      return src[key];
    }
  }
  return nil;
}

NSDictionary *FBCleanupElements(NSDictionary *src)
{
  NSMutableDictionary *result = src.mutableCopy;
  for (NSString* key in src) {
    if ([key.lowercaseString isEqualToString:W3C_ELEMENT_KEY.lowercaseString]
        || [key.lowercaseString isEqualToString:JSONWP_ELEMENT_KEY.lowercaseString]) {
      [result removeObjectForKey:key];
    }
  }
  return result.copy;
}

NSArray<NSString *> *standardCapabilities(void)
{
  static NSArray<NSString *> *standardCaps;
  static dispatch_once_t onceStandardCaps;
  dispatch_once(&onceStandardCaps, ^{
    standardCaps = @[
      @"browserName",
      @"browserVersion",
      @"platformName",
      @"acceptInsecureCerts",
      @"pageLoadStrategy",
      @"proxy",
      @"setWindowRect",
      @"timeouts",
      @"unhandledPromptBehavior"
    ];
  });
  return standardCaps;
}

BOOL isStandardCap(NSString *capName)
{
  return [standardCapabilities() containsObject:capName];
}

NSDictionary<NSString *, id> *_Nullable mergeCaps(NSDictionary<NSString *, id> *primary, NSDictionary<NSString *, id> *secondary, NSError **error)
{
  NSMutableDictionary<NSString *, id> *result = primary.mutableCopy;
  for (NSString *capName in secondary) {
    if (nil != result[capName]) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Property '%@' should not exist on both primary (%@) and secondary (%@) objects", capName, primary, secondary]
       buildError:error];
      return nil;
    }
    [result setObject:(id) secondary[capName] forKey:capName];
  }
  return result.copy;
}

NSDictionary<NSString *, id> *_Nullable stripPrefixes(NSDictionary<NSString *, id> *caps, NSError **error)
{
  NSString* prefix = [NSString stringWithFormat:@"%@:", APPIUM_PREFIX];
  NSMutableDictionary<NSString *, id> *filteredCaps = [NSMutableDictionary dictionary];
  NSMutableArray<NSString *> *badPrefixedCaps = [NSMutableArray array];
  for (NSString *capName in caps) {
    if (![capName hasPrefix:prefix]) {
      [filteredCaps setObject:(id) caps[capName] forKey:capName];
      continue;
    }

    NSString *strippedName = [capName substringFromIndex:prefix.length];
    [filteredCaps setObject:(id) caps[capName] forKey:strippedName];
    if (isStandardCap(strippedName)) {
      [badPrefixedCaps addObject:strippedName];
    }
  }
  if (badPrefixedCaps.count > 0) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"The capabilities %@ are standard and should not have the '%@' prefix", badPrefixedCaps, prefix]
     buildError:error];
    return nil;
  }
  return filteredCaps.copy;
}

NSDictionary<NSString *, id> *FBParseCapabilities(NSDictionary<NSString *, id> *caps, NSError **error)
{
  NSDictionary<NSString *, id> *alwaysMatch = caps[ALWAYS_MATCH_KEY] ?: @{};
  NSArray<NSDictionary<NSString *, id> *> *firstMatch = caps[FIRST_MATCH_KEY] ?: @[];
  NSArray<NSDictionary<NSString *, id> *> *allFirstMatchCaps = firstMatch.count == 0 ? @[@{}] : firstMatch;
  NSDictionary<NSString *, id> *requiredCaps;
  if (nil == (requiredCaps = stripPrefixes(alwaysMatch, error))) {
    return nil;
  }
  for (NSDictionary<NSString *, id> *fmc in allFirstMatchCaps) {
    NSDictionary<NSString *, id> *strippedCaps;
    if (nil == (strippedCaps = stripPrefixes(fmc, error))) {
      return nil;
    }
    NSDictionary<NSString *, id> *mergedCaps;
    if (nil == (mergedCaps = mergeCaps(requiredCaps, strippedCaps, error))) {
      [FBLogger logFmt:@"%@", (*error).description];
      continue;
    }
    return mergedCaps;
  }
  [[[FBErrorBuilder builder]
    withDescriptionFormat:@"Could not find matching capabilities from %@", caps]
   buildError:error];
  return nil;
}
