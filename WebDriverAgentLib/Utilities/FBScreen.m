/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScreen.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXCodeCompatibility.h"
#import "XCUIScreen.h"

@implementation FBScreen

+ (long long)displayID
{
  return XCUIScreen.mainScreen.displayID;
}

+ (double)scale
{
  return [XCUIScreen.mainScreen scale];
}

@end
