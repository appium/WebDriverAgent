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
  if (0 == [self.value fb_visualLength]) {
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
  NSUInteger preClearTextLength = 0;
  while ((preClearTextLength = [self.value fb_visualLength]) > 0) {
    NSString *textToType = [backspaceDeleteSequence fb_repeatTimes:preClearTextLength];
    if (retry >= MAX_CLEAR_RETRIES - 1) {
      // Last chance retry. Try to select the content of the field using the context menu
      [self pressForDuration:1.0];
      XCUIElement *selectAll = self.application.menuItems[@"Select All"];
      if ([selectAll waitForExistenceWithTimeout:0.5]) {
        [selectAll tap];
        textToType = backspaceDeleteSequence;
      }
    }
    if (![FBKeyboard typeText:textToType error:error]) {
      return NO;
    }
    
    if (retry >= MAX_CLEAR_RETRIES - 1) {
      return [[[FBErrorBuilder builder]
                 withDescriptionFormat:@"Cannot clear the value of '%@'", self.description]
                buildError:error];
    }
    
    retry++;
  }
  return YES;
}

@end
