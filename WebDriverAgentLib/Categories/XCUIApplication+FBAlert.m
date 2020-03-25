/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBAlert.h"

#import "FBXCodeCompatibility.h"

@implementation XCUIApplication (FBAlert)

- (XCUIElement *)fb_alertElement
{
  NSPredicate *alertCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu}",
                                          XCUIElementTypeAlert, XCUIElementTypeSheet];
  XCUIElement *alert = [[self descendantsMatchingType:XCUIElementTypeAny]
                      matchingPredicate:alertCollectorPredicate].fb_firstMatch;
  if (nil == alert) {
    return nil;
  }
  BOOL isPhone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
  if (!isPhone
      && alert.elementType != XCUIElementTypeAlert
      && nil == [self.query matchingIdentifier:@"PopoverDismissRegion"].fb_firstMatch) {
    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    return nil;
  }
  return alert;
}

@end
