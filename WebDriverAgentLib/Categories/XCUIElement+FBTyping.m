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
    return YES;
  }

  if (![self fb_prepareForTextInputWithError:error]) {
    return NO;
  }
  
  NSUInteger preClearTextLength = 0;
  NSData *encodedSequence = [@"\\u0008\\u007F" dataUsingEncoding:NSASCIIStringEncoding];
  NSString *backspaceDeleteSequence = [[NSString alloc] initWithData:encodedSequence encoding:NSNonLossyASCIIStringEncoding];
  while ([self.value fb_visualLength] != preClearTextLength) {
    NSMutableString *textToType = @"".mutableCopy;
    preClearTextLength = [self.value fb_visualLength];
    for (NSUInteger i = 0 ; i < preClearTextLength ; i++) {
      [textToType appendString:backspaceDeleteSequence];
    }
    if (textToType.length > 0 && ![FBKeyboard typeText:textToType error:error]) {
      return NO;
    }
  }
  return YES;
}

@end
