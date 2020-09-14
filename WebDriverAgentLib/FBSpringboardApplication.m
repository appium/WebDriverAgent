/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSpringboardApplication.h"

#import "FBRunLoopSpinner.h"
#import "FBXCodeCompatibility.h"

#if TARGET_OS_TV
#import "XCUIElement+FBTVFocuse.h"

NSString *const SPRINGBOARD_BUNDLE_ID = @"com.apple.HeadBoard";
#else
NSString *const SPRINGBOARD_BUNDLE_ID = @"com.apple.springboard";
#endif

@implementation FBSpringboardApplication

+ (instancetype)fb_springboard
{
  static FBSpringboardApplication *_springboardApp;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _springboardApp = [[FBSpringboardApplication alloc] initPrivateWithPath:nil bundleID:SPRINGBOARD_BUNDLE_ID];
  });
  return _springboardApp;
}

- (BOOL)fb_switchToWithError:(NSError **)error
{
  @try {
    if ([self fb_state] < 2) {
      [self launch];
    } else {
      [self fb_activate];
    }
  } @catch (NSException *e) {
    return [[[FBErrorBuilder alloc]
             withDescription:nil == e ? @"Cannot open SpringBoard" : e.reason]
            buildError:error];
  }
  return [[[[FBRunLoopSpinner new]
            timeout:5]
           timeoutErrorMessage:@"Timeout waiting until SpringBoard is visible"]
          spinUntilTrue:^BOOL{ return [FBApplication.fb_activeApplication.bundleID isEqualToString:SPRINGBOARD_BUNDLE_ID]; }
          error:error];
}

@end
