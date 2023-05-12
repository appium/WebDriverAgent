/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBAlert.h"

#import "FBMacros.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBUtilities.h"

#define MAX_CENTER_DELTA 10.0

NSString *const FB_SAFARI_APP_NAME = @"Safari";


@implementation XCUIApplication (FBAlert)

- (nullable XCUIElement *)fb_alertElementFromSafariWithScrollView:(XCUIElement *)scrollView
                                                     viewSnapshot:(id<FBXCElementSnapshot>)viewSnapshot
{
  CGRect appFrame = viewSnapshot.frame;
  NSPredicate *dstViewMatchPredicate = [NSPredicate predicateWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot, NSDictionary *bindings) {
    CGRect curFrame = snapshot.frame;
    if (!CGRectEqualToRect(appFrame, curFrame)
        && curFrame.origin.x > 0 && curFrame.size.width < appFrame.size.width) {
      CGFloat possibleCenterX = (appFrame.size.width - curFrame.size.width) / 2;
      return fabs(possibleCenterX - curFrame.origin.x) < MAX_CENTER_DELTA;
    }
    return NO;
  }];
  NSPredicate *dstViewContainPredicate1 = [NSPredicate predicateWithFormat:@"elementType == %lu", XCUIElementTypeTextView];
  NSPredicate *dstViewContainPredicate2 = [NSPredicate predicateWithFormat:@"elementType == %lu", XCUIElementTypeButton];
  // Find the first XCUIElementTypeOther which is the grandchild of the web view
  // and is horizontally aligned to the center of the screen
  XCUIElement *candidate = [[[[[[scrollView descendantsMatchingType:XCUIElementTypeAny]
       matchingIdentifier:@"WebView"]
      descendantsMatchingType:XCUIElementTypeOther]
     matchingPredicate:dstViewMatchPredicate]
    containingPredicate:dstViewContainPredicate1]
   containingPredicate:dstViewContainPredicate2].allElementsBoundByIndex.firstObject;

  if (nil == candidate) {
    return nil;
  }
  // ...and contains one to two buttons
  // and conatins at least one text view
  __block NSUInteger buttonsCount = 0;
  __block NSUInteger textViewsCount = 0;
  id<FBXCElementSnapshot> snapshot = candidate.fb_cachedSnapshot ?: candidate.fb_takeSnapshot;
  [snapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
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
  XCUIElement *alert = [[self descendantsMatchingType:XCUIElementTypeAny]
                        matchingPredicate:alertCollectorPredicate].allElementsBoundByIndex.firstObject;
  if (nil == alert) {
    return nil;
  }
  id<FBXCElementSnapshot> alertSnapshot = alert.fb_cachedSnapshot ?: alert.fb_takeSnapshot;

  if (alertSnapshot.elementType == XCUIElementTypeAlert) {
    return alert;
  }

  if (alertSnapshot.elementType == XCUIElementTypeSheet) {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
      return alert;
    }

    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    id<FBXCElementSnapshot> ancestor = alertSnapshot.parent;
    while (nil != ancestor) {
      if (nil != ancestor.identifier && [ancestor.identifier isEqualToString:@"PopoverDismissRegion"]) {
        return nil;
      }
      ancestor = ancestor.parent;
    }
    return alert;
  }

  if (alertSnapshot.elementType == XCUIElementTypeScrollView) {
    id<FBXCElementSnapshot> app = [[FBXCElementSnapshotWrapper ensureWrapped:alertSnapshot] fb_parentMatchingType:XCUIElementTypeApplication];
    if (nil != app && [app.label isEqualToString:FB_SAFARI_APP_NAME]) {
      // Check alert presence in Safari web view
      return [self fb_alertElementFromSafariWithScrollView:alert viewSnapshot:alertSnapshot];
    }
  }

  return nil;
}

@end
