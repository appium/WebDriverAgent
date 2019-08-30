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

- (BOOL)fb_waitUntilApplicationBoardIsVisible:(NSError **)error
{
  return
  [[[[FBRunLoopSpinner new]
     timeout:10.]
    timeoutErrorMessage:@"Timeout waiting until SpringBoard is visible"]
   spinUntilTrue:^BOOL{
     return self.fb_isApplicationBoardVisible;
   } error:error];
}

- (BOOL)fb_isApplicationBoardVisible
{
  [self fb_nativeResolve];
#if TARGET_OS_TV
  // GridCollectionView works for simulator and real device so far
  return self.collectionViews[@"GridCollectionView"].isEnabled;
#else
  // the dock (and other icons) don't seem to be consistently reported as
  // visible. esp on iOS 11 but also on 10.3.3
  return self.otherElements[@"Dock"].isEnabled;
#endif
}

@end
