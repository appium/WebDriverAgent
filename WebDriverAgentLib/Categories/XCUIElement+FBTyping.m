/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBTyping.h"

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBKeyboard.h"
#import "NSString+FBVisualLength.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBUtilities.h"
#import "FBXCodeCompatibility.h"

#define MAX_CLEAR_RETRIES 2


@interface NSString (FBRepeat)

- (NSString *)fb_repeatTimes:(NSUInteger)times;

@end

@implementation NSString (FBRepeat)

- (NSString *)fb_repeatTimes:(NSUInteger)times {
  return [@"" stringByPaddingToLength:times * self.length
                           withString:self
                      startingAtIndex:0];
}

@end


@implementation XCUIElement (FBTyping)

- (BOOL)fb_hasKeyboardFocus
{
  // https://developer.apple.com/documentation/xctest/xcuielement/1500968-typetext?language=objc
  // > The element or a descendant must have keyboard focus; otherwise an error is raised.
  return self.hasKeyboardFocus || [[[self.fb_query descendantsMatchingType:XCUIElementTypeAny]
   matchingPredicate:[NSPredicate predicateWithFormat:@"hasKeyboardFocus == YES"]]
  count] > 0;
}

- (BOOL)fb_prepareForTextInputWithError:(NSError **)error
{
  if (self.fb_hasKeyboardFocus) {
    return YES;
  }

// There is no possibility to open the keyboard by tapping a field in TvOS
#if !TARGET_OS_TV
  [self fb_tapWithError:nil];
  // It might take some time to update the UI
  [self fb_waitUntilSnapshotIsStableWithTimeout:1];
  if (self.fb_hasKeyboardFocus) {
    return YES;
  }
#endif

  [FBLogger logFmt:@"'%@' is not ready for a text input. Neither the accessibility element itself nor its accessible descendants have the input focus. Continuing anyway", self.description];
  return YES;
}

- (BOOL)fb_typeText:(NSString *)text error:(NSError **)error
{
  return [self fb_typeText:text frequency:[FBConfiguration maxTypingFrequency] error:error];
}

- (BOOL)fb_typeText:(NSString *)text frequency:(NSUInteger)frequency error:(NSError **)error
{
  return [self fb_prepareForTextInputWithError:error]
    && [FBKeyboard typeText:text frequency:frequency error:error];
}

- (BOOL)fb_clearTextWithError:(NSError **)error
{
  id currentValue = self.value;
  if (nil != currentValue && ![currentValue isKindOfClass:NSString.class]) {
    return [[[FBErrorBuilder builder]
               withDescriptionFormat:@"The value of '%@' element is not a string and thus cannot be cleared", self.description]
              buildError:error];
  }
  
  if (nil == currentValue || 0 == [currentValue fb_visualLength]) {
    // Short circuit if the content is not present
    return YES;
  }

  if (![self fb_prepareForTextInputWithError:error]) {
    return NO;
  }
  
  static NSString *backspaceDeleteSequence;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    backspaceDeleteSequence = [[NSString alloc] initWithData:(NSData *)[@"\\u0008\\u007F" dataUsingEncoding:NSASCIIStringEncoding]
                                                    encoding:NSNonLossyASCIIStringEncoding];
  });
  
  NSUInteger retry = 0;
  NSString *placeholderValue = self.placeholderValue;
  NSUInteger preClearTextLength = [currentValue fb_visualLength];
  do {
    if (retry >= MAX_CLEAR_RETRIES - 1) {
      // Last chance retry. Tripple-tap the field to select its content
      [self tapWithNumberOfTaps:3 numberOfTouches:1];
      return [FBKeyboard typeText:backspaceDeleteSequence error:error];
    }

    NSString *textToType = [backspaceDeleteSequence fb_repeatTimes:preClearTextLength];
    if (![FBKeyboard typeText:textToType error:error]) {
      return NO;
    }

    currentValue = self.value;
    if (nil != placeholderValue && [currentValue isEqualToString:placeholderValue]) {
      // Short circuit if only the placeholder value left
      return YES;
    }
    preClearTextLength = [currentValue fb_visualLength];

    retry++;
  } while (preClearTextLength > 0);
  return YES;
}

@end
