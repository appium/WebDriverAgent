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


#define MAX_CLEAR_RETRIES 3

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

- (BOOL)fb_prepareForTextInputWithError:(NSError **)error
{
  BOOL wasKeyboardAlreadyVisible = [FBKeyboard waitUntilVisibleForApplication:self.application timeout:-1 error:error];
  if (wasKeyboardAlreadyVisible && self.hasKeyboardFocus) {
    return YES;
  }

  BOOL isKeyboardVisible = wasKeyboardAlreadyVisible;
  // Sometimes the keyboard is not opened after the first tap, so we need to retry
  for (int tryNum = 0; tryNum < 2; ++tryNum) {
    if ([self fb_tapWithError:error] && wasKeyboardAlreadyVisible) {
      return YES;
    }
    // It might take some time to update the UI
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    [self fb_waitUntilSnapshotIsStable];
    isKeyboardVisible = [FBKeyboard waitUntilVisibleForApplication:self.application timeout:-1 error:error];
    if (isKeyboardVisible && self.hasKeyboardFocus) {
      return YES;
    }
  }
  if (nil == error) {
    NSString *description = [NSString stringWithFormat:@"The element '%@' is not ready for text input (hasKeyboardFocus -> %@, isKeyboardVisible -> %@)", self.description, @(self.hasKeyboardFocus), @(isKeyboardVisible)];
    return [[[FBErrorBuilder builder] withDescription:description] buildError:error];
  }
  return NO;
}

- (BOOL)fb_typeText:(NSString *)text error:(NSError **)error
{
  return [self fb_typeText:text frequency:[FBConfiguration maxTypingFrequency] error:error];
}

- (BOOL)fb_typeText:(NSString *)text frequency:(NSUInteger)frequency error:(NSError **)error
{
  // There is no ability to open text field via tap
#if TARGET_OS_TV
  if (!self.hasKeyboardFocus) {
    return [[[FBErrorBuilder builder] withDescription:@"Keyboard is not opened."] buildError:error];
  }
#else
  if (![self fb_prepareForTextInputWithError:error]) {
    return NO;
  }
#endif
  if (![FBKeyboard typeText:text frequency:frequency error:error]) {
    return NO;
  }
  return YES;
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
