/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTouchIDCommands.h"

#import "FBRouteRequest.h"

#import "XCUIDevice+FBHelpers.h"

@implementation FBTouchIDCommands

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/wda/touch_id"] respondWithBlock: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      BOOL isMatch = [request.arguments[@"match"] boolValue];
      if (![[XCUIDevice sharedDevice] fb_fingerTouchShouldMatch:isMatch]) {
        return FBResponseWithUnknownErrorFormat(@"Cannot perform Touch Id %@match", isMatch ? @"" : @"non-");
      }
      return FBResponseWithOK();
    }],
  ];
}

@end
