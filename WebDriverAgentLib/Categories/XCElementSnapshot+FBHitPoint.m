/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCElementSnapshot+FBHitPoint.h"

#import "FBLogger.h"
#import "XCUIHitPointResult.h"
#import "XCElementSnapshot+FBHelpers.h"

@implementation XCElementSnapshot (FBHitPoint)

- (NSValue *)fb_hitPoint
{
  NSError *error;
  XCUIHitPointResult *result = [self hitPoint:&error];
  if (nil != error) {
    [FBLogger logFmt:@"Failed to fetch hit point for %@ - %@", self.fb_description, error.localizedDescription];
    return nil;
  }
  return [NSValue valueWithCGPoint:result.hitPoint];
}

@end
