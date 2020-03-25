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

#define MAX_CENTER_DELTA 10.0

NSString *const FB_SAFARI_APP_NAME = @"Safari";


@implementation XCUIApplication (FBAlert)

- (nullable XCUIElement *)fb_alertElementFromSafariWithScrollView:(XCUIElement *)scrollView
{
  CGRect appFrame = self.frame;
  NSPredicate *dstViewPredicate = [NSPredicate predicateWithBlock:^BOOL(XCElementSnapshot *snapshot, NSDictionary *bindings) {
    CGRect curFrame = snapshot.frame;
    if (!CGRectEqualToRect(appFrame, curFrame)
        && curFrame.origin.x > 0 && curFrame.size.width < appFrame.size.width) {
      CGFloat possibleCenterX = (appFrame.size.width - curFrame.size.width) / 2;
      return fabs(possibleCenterX - curFrame.origin.x) < MAX_CENTER_DELTA;
    }
    return NO;
  }];
  // Find the first XCUIElementTypeOther which is the grandchild of the web view
  // and is horizontally aligned to the center of the screen
  XCUIElement *candidate = [[[[[scrollView descendantsMatchingType:XCUIElementTypeAny]
                               matchingIdentifier:@"WebView"]
                              childrenMatchingType:XCUIElementTypeOther]
                             childrenMatchingType:XCUIElementTypeOther]
                            matchingPredicate:dstViewPredicate].fb_firstMatch;
  if (nil == candidate) {
    return nil;
  }
  // ...and contains one to two buttons
  // and conatins at least one text view
  __block NSUInteger buttonsCount = 0;
  __block NSUInteger textViewsCount = 0;
  [candidate.fb_lastSnapshot enumerateDescendantsUsingBlock:^(XCElementSnapshot *descendant) {
    XCUIElementType curType = descendant.elementType;
    if (curType == XCUIElementTypeButton) {
      buttonsCount++;
    } else if (curType == XCUIElementTypeTextView) {
      textViewsCount++;
    }
  }];
  return (buttonsCount >= 1 && buttonsCount <= 2 && textViewsCount > 0) ? candidate : nil;
}

- (XCUIElement *)fb_alertElement
{
  NSPredicate *alertCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu,%lu}",
                                          XCUIElementTypeAlert, XCUIElementTypeSheet, XCUIElementTypeScrollView];
  XCUIElement *alert = [[self.fb_query descendantsMatchingType:XCUIElementTypeAny]
                      matchingPredicate:alertCollectorPredicate].fb_firstMatch;
  XCUIElementType alertType = alert.elementType;
  if (alertType == XCUIElementTypeAlert) {
    return alert;
  }

  if (alertType == XCUIElementTypeSheet) {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
      return alert;
    }

    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    return (nil == [self.fb_query matchingIdentifier:@"PopoverDismissRegion"].fb_firstMatch) ? alert : nil;
  }

  if (alertType == XCUIElementTypeScrollView && [self.label isEqualToString:FB_SAFARI_APP_NAME]) {
    // Check alert presence in Safari web view
    return [self fb_alertElementFromSafariWithScrollView:alert];
  }

  return nil;
}

@end
