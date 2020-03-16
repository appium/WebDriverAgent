/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCAccessibilityElement+FBComparison.h"
#import "FBElementUtils.h"

@implementation XCAccessibilityElement (FBComparison)

- (BOOL)fb_isEqualToElement:(XCAccessibilityElement *)other
{
  if (nil == other) {
    return NO;
  }
  return [[FBElementUtils uidWithAccessibilityElement:self]
          isEqualToString:([FBElementUtils uidWithAccessibilityElement:other] ?: @"")];
}

@end
