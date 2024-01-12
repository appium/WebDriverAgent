/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBKeyboard.h"

#import "FBConfiguration.h"
#import "FBXCTestDaemonsProxy.h"
#import "FBErrorBuilder.h"
#import "FBRunLoopSpinner.h"
#import "FBMacros.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCTestDriver.h"
#import "FBLogger.h"
#import "FBConfiguration.h"

@implementation FBKeyboard

+ (BOOL)waitUntilVisibleForApplication:(XCUIApplication *)app 
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error
{
  BOOL (^isKeyboardVisible)(void) = ^BOOL(void) {
    XCUIElement *keyboard = app.keyboards.fb_firstMatch;
    if (nil == keyboard) {
      return NO;
    }

    NSPredicate *keySearchPredicate = [NSPredicate predicateWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot,
                                                                            NSDictionary *bindings) {
      return snapshot.label.length > 0;
    }];
    XCUIElement *firstKey = [[keyboard descendantsMatchingType:XCUIElementTypeKey]
                             matchingPredicate:keySearchPredicate].allElementsBoundByIndex.firstObject;
    return firstKey.exists && firstKey.hittable;
  };
  NSString* errMessage = @"The on-screen keyboard must be present to send keys";
  if (timeout <= 0) {
    if (!isKeyboardVisible()) {
      return [[[FBErrorBuilder builder] withDescription:errMessage] buildError:error];
    }
    return YES;
  }
  return
    [[[[FBRunLoopSpinner new]
       timeout:timeout]
      timeoutErrorMessage:errMessage]
     spinUntilTrue:isKeyboardVisible
     error:error];
}

#if (!TARGET_OS_TV && __clang_major__ >= 15)

+ (NSString *)keyValueForName:(NSString *)name
{
  static dispatch_once_t onceKeys;
  static NSDictionary<NSString *, NSString *> *keysMapping;
  dispatch_once(&onceKeys, ^{
    keysMapping = @{
      @"XCUIKeyboardKeyDelete": XCUIKeyboardKeyDelete,
      @"XCUIKeyboardKeyReturn": XCUIKeyboardKeyReturn,
      @"XCUIKeyboardKeyEnter": XCUIKeyboardKeyEnter,
      @"XCUIKeyboardKeyTab": XCUIKeyboardKeyTab,
      @"XCUIKeyboardKeySpace": XCUIKeyboardKeySpace,
      @"XCUIKeyboardKeyEscape": XCUIKeyboardKeyEscape,

      @"XCUIKeyboardKeyUpArrow": XCUIKeyboardKeyUpArrow,
      @"XCUIKeyboardKeyDownArrow": XCUIKeyboardKeyDownArrow,
      @"XCUIKeyboardKeyLeftArrow": XCUIKeyboardKeyLeftArrow,
      @"XCUIKeyboardKeyRightArrow": XCUIKeyboardKeyRightArrow,

      @"XCUIKeyboardKeyF1": XCUIKeyboardKeyF1,
      @"XCUIKeyboardKeyF2": XCUIKeyboardKeyF2,
      @"XCUIKeyboardKeyF3": XCUIKeyboardKeyF3,
      @"XCUIKeyboardKeyF4": XCUIKeyboardKeyF4,
      @"XCUIKeyboardKeyF5": XCUIKeyboardKeyF5,
      @"XCUIKeyboardKeyF6": XCUIKeyboardKeyF6,
      @"XCUIKeyboardKeyF7": XCUIKeyboardKeyF7,
      @"XCUIKeyboardKeyF8": XCUIKeyboardKeyF8,
      @"XCUIKeyboardKeyF9": XCUIKeyboardKeyF9,
      @"XCUIKeyboardKeyF10": XCUIKeyboardKeyF10,
      @"XCUIKeyboardKeyF11": XCUIKeyboardKeyF11,
      @"XCUIKeyboardKeyF12": XCUIKeyboardKeyF12,
      @"XCUIKeyboardKeyF13": XCUIKeyboardKeyF13,
      @"XCUIKeyboardKeyF14": XCUIKeyboardKeyF14,
      @"XCUIKeyboardKeyF15": XCUIKeyboardKeyF15,
      @"XCUIKeyboardKeyF16": XCUIKeyboardKeyF16,
      @"XCUIKeyboardKeyF17": XCUIKeyboardKeyF17,
      @"XCUIKeyboardKeyF18": XCUIKeyboardKeyF18,
      @"XCUIKeyboardKeyF19": XCUIKeyboardKeyF19,

      @"XCUIKeyboardKeyForwardDelete": XCUIKeyboardKeyForwardDelete,
      @"XCUIKeyboardKeyHome": XCUIKeyboardKeyHome,
      @"XCUIKeyboardKeyEnd": XCUIKeyboardKeyEnd,
      @"XCUIKeyboardKeyPageUp": XCUIKeyboardKeyPageUp,
      @"XCUIKeyboardKeyPageDown": XCUIKeyboardKeyPageDown,
      @"XCUIKeyboardKeyClear": XCUIKeyboardKeyClear,
      @"XCUIKeyboardKeyHelp": XCUIKeyboardKeyHelp,

      @"XCUIKeyboardKeyCapsLock": XCUIKeyboardKeyCapsLock,
      @"XCUIKeyboardKeyShift": XCUIKeyboardKeyShift,
      @"XCUIKeyboardKeyControl": XCUIKeyboardKeyControl,
      @"XCUIKeyboardKeyOption": XCUIKeyboardKeyOption,
      @"XCUIKeyboardKeyCommand": XCUIKeyboardKeyCommand,
      @"XCUIKeyboardKeyRightShift": XCUIKeyboardKeyRightShift,
      @"XCUIKeyboardKeyRightControl": XCUIKeyboardKeyRightControl,
      @"XCUIKeyboardKeyRightOption": XCUIKeyboardKeyRightOption,
      @"XCUIKeyboardKeyRightCommand": XCUIKeyboardKeyRightCommand,
      @"XCUIKeyboardKeySecondaryFn": XCUIKeyboardKeySecondaryFn
    };
  });
  return keysMapping[name];
}

#endif

@end
