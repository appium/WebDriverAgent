/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBTyping.h"

#import "FBErrorBuilder.h"
#import "FBKeyboard.h"
#import "NSString+FBVisualLength.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBUtilities.h"

@implementation XCUIElement (FBTyping)

- (BOOL)fb_prepareForTextInputWithError:(NSError **)error
{
  BOOL isKeyboardAlredyVisible = [FBKeyboard waitUntilVisibleForApplication:self.application timeout:-1 error:error];
  if (isKeyboardAlredyVisible && self.hasKeyboardFocus) {
    return YES;
  }
  
  int retriesCount = 2;
  int tryNum = 0;
  while (tryNum < retriesCount) {
    if (![self fb_tapWithError:error]) {
      return NO;
    }
    if (isKeyboardAlredyVisible) {
      return YES;
    }
    [self fb_waitUntilSnapshotIsStable];
    if ([FBKeyboard waitUntilVisibleForApplication:self.application timeout:1. error:error]) {
      return YES;
    }
    // Sometimes the keyboard is not opened after the first try, so we need to retry
    ++tryNum;
  }
  return NO;
}

- (BOOL)fb_typeText:(NSString *)text error:(NSError **)error
{
  if (![self fb_prepareForTextInputWithError:error]) {
    return NO;
  }
  
  if (![FBKeyboard typeText:text error:error]) {
    return NO;
  }
  return YES;
}

- (BOOL)fb_clearTextWithError:(NSError **)error
{
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
    if (![FBKeyboard typeText:textToType error:error]) {
      return NO;
    }
  }
  return YES;
}

@end
