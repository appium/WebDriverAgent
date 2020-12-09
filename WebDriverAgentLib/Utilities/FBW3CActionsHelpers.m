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

BOOL FBIsMetaModifier(NSString *value)
{
  unichar charCode = [value characterAtIndex:0];
  return charCode >= 0xE000 && charCode <= 0xF8FF;
}

NSUInteger FBToMetaModifier(NSString *value)
{
  if (!FBIsMetaModifier(value)) {
    return 0;
  }

  unichar charCode = [value characterAtIndex:0];
  switch (charCode) {
    case 0xE000:
      return XCUIKeyModifierNone;
    case 0xE03D:
      return XCUIKeyModifierCommand;
    case 0xE009:
      return XCUIKeyModifierControl;
    case 0xE00A:
      return XCUIKeyModifierOption;
    case 0xE008:
      return XCUIKeyModifierShift;
    default:
      [FBLogger logFmt:@"Skipping the unsupported meta modifier with code %@", @(charCode)];
      return 0;
  }
}
