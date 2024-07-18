/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import "FBW3CActionsHelpers.h"

#import "FBErrorBuilder.h"
#import "XCUIElement.h"
#import "FBLogger.h"

static NSString *const FB_ACTION_ITEM_KEY_VALUE = @"value";
static NSString *const FB_ACTION_ITEM_KEY_DURATION = @"duration";

NSString *FBRequireValue(NSDictionary<NSString *, id> *actionItem, NSError **error)
{
  id value = [actionItem objectForKey:FB_ACTION_ITEM_KEY_VALUE];
  if (![value isKindOfClass:NSString.class] || [value length] == 0) {
    NSString *description = [NSString stringWithFormat:@"Key value must be present and should be a valid non-empty string for '%@'", actionItem];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return nil;
  }
  NSRange r = [(NSString *)value rangeOfComposedCharacterSequenceAtIndex:0];
  return [(NSString *)value substringWithRange:r];
}

NSNumber *_Nullable FBOptDuration(NSDictionary<NSString *, id> *actionItem, NSNumber *defaultValue, NSError **error)
{
  NSNumber *durationObj = [actionItem objectForKey:FB_ACTION_ITEM_KEY_DURATION];
  if (nil == durationObj) {
    if (nil == defaultValue) {
      NSString *description = [NSString stringWithFormat:@"Duration must be present for '%@' action item", actionItem];
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:description] build];
      }
      return nil;
    }
    return defaultValue;
  }
  if ([durationObj doubleValue] < 0.0) {
    NSString *description = [NSString stringWithFormat:@"Duration must be a valid positive number for '%@' action item", actionItem];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return nil;
  }
  return durationObj;
}

NSString *FBMapIfSpecialCharacter(NSString *value)
{
  if (0 == [value length]) {
    return value;
  }

  unichar charCode = [value characterAtIndex:0];
  switch (charCode) {
    case 0xE000:
      return @"";
    case 0xE003:
      return [NSString stringWithFormat:@"%C", 0x0008];
    case 0xE004:
      return [NSString stringWithFormat:@"%C", 0x0009];
    case 0xE006:
      return [NSString stringWithFormat:@"%C", 0x000D];
    case 0xE007:
      return [NSString stringWithFormat:@"%C", 0x000A];
    case 0xE00C:
      return [NSString stringWithFormat:@"%C", 0x001B];
    case 0xE00D:
    case 0xE05D:
      return @" ";
    case 0xE017:
      return [NSString stringWithFormat:@"%C", 0x007F];
    case 0xE018:
      return @";";
    case 0xE019:
      return @"=";
    case 0xE01A:
      return @"0";
    case 0xE01B:
      return @"1";
    case 0xE01C:
      return @"2";
    case 0xE01D:
      return @"3";
    case 0xE01E:
      return @"4";
    case 0xE01F:
      return @"5";
    case 0xE020:
      return @"6";
    case 0xE021:
      return @"7";
    case 0xE022:
      return @"8";
    case 0xE023:
      return @"9";
    case 0xE024:
      return @"*";
    case 0xE025:
      return @"+";
    case 0xE026:
      return @",";
    case 0xE027:
      return @"-";
    case 0xE028:
      return @".";
    case 0xE029:
      return @"/";
    default:
      return charCode >= 0xE000 && charCode <= 0xE05D ? @"" : value;
  }
}
