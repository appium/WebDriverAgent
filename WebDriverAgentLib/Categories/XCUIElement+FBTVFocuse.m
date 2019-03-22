/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBTVFocuse.h"

#import <XCTest/XCUIRemote.h>
#import "FBApplication.h"
#import "FBErrorBuilder.h"
#import <FBTVNavigationTracker.h>
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

#if TARGET_OS_TV

int const MAX_ITERATIONS_COUNT = 100;

@implementation XCUIElement (FBTVFocuse)

- (BOOL)fb_setFocusWithError:(NSError**) error
{
  [[FBApplication fb_activeApplication] fb_waitUntilSnapshotIsStable];

  if (!self.wdEnabled) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Element could not be focused."] build];
    }
    return NO;
  }

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:self];
  for (int i = 0; i < MAX_ITERATIONS_COUNT; i++) {
    if (self.hasFocus) {
      return YES;
    }

    if (!self.exists) {
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:@"Unable to reach element. Try to use XCUIRemote commands."] build];
      }
      return NO;
    }

    FBTVDirection direction = tracker.directionToMoveFocuse;
    if (direction != FBTVDirectionNone) {
      [[XCUIRemote sharedRemote] pressButton: (XCUIRemoteButton)direction];
    }
  }

  return NO;
}

- (BOOL)fb_selectWithError:(NSError**) error
{
  BOOL result = [self fb_setFocusWithError: error];
  if (result) {
    [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonSelect];
  }
  return result;
}
@end

#endif
