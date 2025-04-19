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
#import "FBXCElementSnapshotWrapper.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "NSString+FBVisualLength.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBUtilities.h"
#import "XCSynthesizedEventRecord.h"
#import "XCPointerEventPath.h"

#define MAX_TEXT_ABBR_LEN 12
#define MAX_CLEAR_RETRIES 3

BOOL FBTypeText(NSString *text, NSUInteger typingSpeed, NSError **error)
{
  NSString *name = text.length <= MAX_TEXT_ABBR_LEN
    ? [NSString stringWithFormat:@"Type '%@'", text]
    : [NSString stringWithFormat:@"Type '%@…'", [text substringToIndex:MAX_TEXT_ABBR_LEN]];
  XCSynthesizedEventRecord *eventRecord = [[XCSynthesizedEventRecord alloc] initWithName:name];
  XCPointerEventPath *ep = [[XCPointerEventPath alloc] initForTextInput];
  [ep typeText:text
      atOffset:0.0
   typingSpeed:typingSpeed
  shouldRedact:NO];
  [eventRecord addPointerEventPath:ep];
  return [FBXCTestDaemonsProxy synthesizeEventWithRecord:eventRecord error:error];
}

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


@interface FBXCElementSnapshotWrapper (FBKeyboardFocus)

- (BOOL)fb_hasKeyboardFocus;

@end

@implementation FBXCElementSnapshotWrapper (FBKeyboardFocus)

- (BOOL)fb_hasKeyboardFocus
{
  // https://developer.apple.com/documentation/xctest/xcuielement/1500968-typetext?language=objc
  // > The element or a descendant must have keyboard focus; otherwise an error is raised.
  return self.hasKeyboardFocus || [self descendantsByFilteringWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot) {
    return snapshot.hasKeyboardFocus;
  }].count > 0;
}

@end


@implementation XCUIElement (FBTyping)

- (void)fb_prepareForTextInputWithSnapshot:(FBXCElementSnapshotWrapper *)snapshot
{
  if (snapshot.fb_hasKeyboardFocus) {
    return;
  }

  [FBLogger logFmt:@"Neither the \"%@\" element itself nor its accessible descendants have the keyboard input focus", snapshot.fb_description];
// There is no possibility to open the keyboard by tapping a field in TvOS
#if !TARGET_OS_TV
  [FBLogger logFmt:@"Trying to tap the \"%@\" element to have it focused", snapshot.fb_description];
  [self tap];
  // It might take some time to update the UI
  [self fb_standardSnapshot];
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
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  FBXCElementSnapshotWrapper *wrapped = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  [self fb_prepareForTextInputWithSnapshot:wrapped];
  if (shouldClear && ![self fb_clearTextWithSnapshot:wrapped shouldPrepareForInput:NO error:error]) {
    return NO;
  }
  return FBTypeText(text, frequency, error);
}

- (BOOL)fb_clearTextWithError:(NSError **)error
{
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  return [self fb_clearTextWithSnapshot:[FBXCElementSnapshotWrapper ensureWrapped:snapshot]
                  shouldPrepareForInput:YES
                                  error:error];
}

- (BOOL)fb_clearTextWithSnapshot:(FBXCElementSnapshotWrapper *)snapshot
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

  NSUInteger preClearTextLength = [currentValue fb_visualLength];
  NSString *backspacesToType = [backspaceDeleteSequence fb_repeatTimes:preClearTextLength];

#if TARGET_OS_IOS
  NSUInteger retry = 0;
  NSString *placeholderValue = snapshot.placeholderValue;
  do {
    // the ios needs to have keyboard focus to clear text
    if (shouldPrepareForInput && 0 == retry) {
      [self fb_prepareForTextInputWithSnapshot:snapshot];
    }

    if (retry == 0 && FBConfiguration.useClearTextShortcut) {
      // 1st attempt is via the IOHIDEvent as the fastest operation
      // https://github.com/appium/appium/issues/19389
      [[XCUIDevice sharedDevice] fb_performIOHIDEventWithPage:0x07  // kHIDPage_KeyboardOrKeypad
                                                        usage:0x9c  // kHIDUsage_KeyboardClear
                                                     duration:0.01
                                                        error:nil];
    } else if (retry >= MAX_CLEAR_RETRIES - 1) {
      // Last chance retry. Tripple-tap the field to select its content
      [self tapWithNumberOfTaps:3 numberOfTouches:1];
      return FBTypeText(backspaceDeleteSequence, FBConfiguration.defaultTypingFrequency, error);
    } else if (!FBTypeText(backspacesToType, FBConfiguration.defaultTypingFrequency, error)) {
      // 2nd operation
      return NO;
    }

    currentValue = [self fb_standardSnapshot].value;
    if (nil != placeholderValue && [currentValue isEqualToString:placeholderValue]) {
      // Short circuit if only the placeholder value left
      return YES;
    }
    preClearTextLength = [currentValue fb_visualLength];

    retry++;
  } while (preClearTextLength > 0);
  return YES;
#else
  // tvOS does not need a focus.
  // kHIDPage_KeyboardOrKeypad did not work for tvOS's search field. (tvOS 17 at least)
  // Tested XCUIElementTypeSearchField and XCUIElementTypeTextView whch were
  // common search field and email/passowrd input in tvOS apps.
  return FBTypeText(backspacesToType, FBConfiguration.defaultTypingFrequency, error);
#endif
}

@end
