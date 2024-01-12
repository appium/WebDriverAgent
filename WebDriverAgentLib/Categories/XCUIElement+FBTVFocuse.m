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
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import <FBTVNavigationTracker.h>
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

#if TARGET_OS_TV

int const MAX_ITERATIONS_COUNT = 100;

@implementation XCUIElement (FBTVFocuse)

- (BOOL)fb_setFocusWithError:(NSError**) error
{
  [XCUIApplication.fb_activeApplication fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];

  if (!self.wdEnabled) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:
                 [NSString stringWithFormat:@"'%@' element cannot be focused because it is disabled", self.description]] build];
    }
    return NO;
  }

  FBTVNavigationTracker *tracker = [FBTVNavigationTracker trackerWithTargetElement:self];
  for (int i = 0; i < MAX_ITERATIONS_COUNT; i++) {
    // Here hasFocus works so far. Maybe, it is because it is handled by `XCUIRemote`...
    if (self.hasFocus) {
      return YES;
    }

    if (!self.exists) {
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:
                   [NSString stringWithFormat:@"'%@' element is not reachable because it does not exist. Try to use XCUIRemote commands.", self.description]] build];
      }
      return NO;
    }

    FBTVDirection direction = tracker.directionToFocusedElement;
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
