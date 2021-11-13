/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBUIInterruptions.h"

#import "FBReflectionUtils.h"
#import "XCUIApplication.h"

@implementation XCUIApplication (FBUIInterruptions)

- (BOOL)fb_doesNotHandleUIInterruptions
{
  return YES;
}

+ (void)fb_disableUIInterruptionsHandling
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FBReplaceMethod([self class],
                    @selector(doesNotHandleUIInterruptions),
                    @selector(fb_doesNotHandleUIInterruptions));
  });
}

@end
