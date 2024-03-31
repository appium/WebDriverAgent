/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreen.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXCodeCompatibility.h"
#import "XCUIScreen.h"

@implementation FBScreen

+ (double)scale
{
  return [XCUIScreen.mainScreen scale];
}

+ (CGSize)statusBarSize
{
  XCUIElement *mainStatusBar = XCUIApplication.fb_systemApplication.statusBars.allElementsBoundByIndex.firstObject;
  if (nil == mainStatusBar) {
    return CGSizeZero;
  }
  return mainStatusBar.frame.size;
}

@end
