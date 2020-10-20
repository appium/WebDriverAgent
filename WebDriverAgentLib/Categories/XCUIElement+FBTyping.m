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
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBCaching.h"
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


@interface XCElementSnapshot (FBKeyboardFocus)

- (BOOL)fb_hasKeyboardFocus;

@end

@implementation XCElementSnapshot (FBKeyboardFocus)

- (BOOL)fb_hasKeyboardFocus
{
  // https://developer.apple.com/documentation/xctest/xcuielement/1500968-typetext?language=objc
  // > The element or a descendant must have keyboard focus; otherwise an error is raised.
  return self.hasKeyboardFocus || [self descendantsByFilteringWithBlock:^BOOL(XCElementSnapshot *snapshot) {
    return snapshot.hasKeyboardFocus;
  }].count > 0;
}

@end


@implementation XCUIElement (FBTyping)

- (void)fb_prepareForTextInputWithSnapshot:(XCElementSnapshot *)snapshot
{
  if (snapshot.fb_hasKeyboardFocus) {
    return;
  }

  [FBLogger logFmt:@"Neither the \"%@\" element itself nor its accessible descendants have the keyboard input focus", snapshot.fb_description];
// There is no possibility to open the keyboard by tapping a field in TvOS
#if !TARGET_OS_TV
  [FBLogger logFmt:@"Trying to tap the \"%@\" element to have it focused", snapshot.fb_description];
  [self fb_tapWithError:nil];
  // It might take some time to update the UI
  [self fb_takeSnapshot];
#endif
}

- (BOOL)fb_typeText:(NSString *)text
        shouldClear:(BOOL)shouldClear
              error:(NSError **)error
{
  return [self fb_typeText:text
               shouldClear:shouldClear
                 frequency:FBConfiguration.maxTypingFrequency
                     error:error];
}

- (BOOL)fb_typeText:(NSString *)text
        shouldClear:(BOOL)shouldClear
          frequency:(NSUInteger)frequency
              error:(NSError **)error
{
  XCElementSnapshot *snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  [self fb_prepareForTextInputWithSnapshot:snapshot];
  if (shouldClear && ![self fb_clearTextWithSnapshot:self.lastSnapshot
                               shouldPrepareForInput:NO
                                               error:error]) {
    return NO;
  }
  return [FBKeyboard typeText:text frequency:frequency error:error];
}

- (BOOL)fb_clearTextWithError:(NSError **)error
{
  XCElementSnapshot *snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  return [self fb_clearTextWithSnapshot:snapshot
                  shouldPrepareForInput:YES
                                  error:error];
}

- (BOOL)fb_clearTextWithSnapshot:(XCElementSnapshot *)snapshot
           shouldPrepareForInput:(BOOL)shouldPrepareForInput
                           error:(NSError **)error
{
  id currentValue = snapshot.value;
  if (nil != currentValue && ![currentValue isKindOfClass:NSString.class]) {
    return [[[FBErrorBuilder builder]
               withDescriptionFormat:@"The value of '%@' is not a string and thus cannot be edited", snapshot.fb_description]
              buildError:error];
  }
  
  if (nil == currentValue || 0 == [currentValue fb_visualLength]) {
    // Short circuit if the content is not present
    return YES;
  }
  
  static NSString *backspaceDeleteSequence;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    backspaceDeleteSequence = [[NSString alloc] initWithData:(NSData *)[@"\\u0008\\u007F" dataUsingEncoding:NSASCIIStringEncoding]
                                                    encoding:NSNonLossyASCIIStringEncoding];
  });
  
  NSUInteger retry = 0;
  NSString *placeholderValue = snapshot.placeholderValue;
  NSUInteger preClearTextLength = [currentValue fb_visualLength];
  do {
    if (retry >= MAX_CLEAR_RETRIES - 1) {
      // Last chance retry. Tripple-tap the field to select its content
      [self tapWithNumberOfTaps:3 numberOfTouches:1];
      return [FBKeyboard typeText:backspaceDeleteSequence error:error];
    }

    NSString *textToType = [backspaceDeleteSequence fb_repeatTimes:preClearTextLength];
    if (shouldPrepareForInput && 0 == retry) {
      [self fb_prepareForTextInputWithSnapshot:snapshot];
    }
    if (![FBKeyboard typeText:textToType error:error]) {
      return NO;
    }

    currentValue = self.fb_takeSnapshot.value;
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
