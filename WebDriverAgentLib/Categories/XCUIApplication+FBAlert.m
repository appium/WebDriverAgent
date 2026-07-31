/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIApplication+FBAlert.h"

#import "FBMacros.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBUtilities.h"

#define MAX_CENTER_DELTA 10.0

NSString *const FB_SAFARI_APP_NAME = @"Safari";

// The iOS 18+ limited access permission prompt (e.g. the "Select Contacts" view)
// runs in a dedicated process that is not reported by fb_activeApplications.
static NSString *const FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID = @"com.apple.ContactsUI.LimitedAccessPromptView";


@implementation XCUIApplication (FBAlert)

+ (nullable XCUIElement *)fb_limitedAccessPromptAlertElement
{
  XCUIApplication *promptApp = [[XCUIApplication alloc] initWithBundleIdentifier:FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID];
  if (promptApp.state < XCUIApplicationStateRunningForeground) {
    return nil;
  }
  return promptApp.fb_alertElement;
}

+ (nullable id<FBXCElementSnapshot>)fb_findSafariAlertSnapshotInScrollView:(id<FBXCElementSnapshot>)scrollViewSnapshot
{
  CGRect appFrame = scrollViewSnapshot.frame;

  __block id<FBXCElementSnapshot> webView = nil;
  [scrollViewSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil == webView && nil != descendant.identifier && [descendant.identifier isEqualToString:@"WebView"]) {
      webView = descendant;
    }
  }];
  if (nil == webView) {
    return nil;
  }

  // Find the first XCUIElementTypeOther which is the grandchild of the web view
  // and is horizontally aligned to the center of the screen, and contains one
  // to two buttons and at least one text view.
  __block id<FBXCElementSnapshot> candidate = nil;
  [webView enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil != candidate || descendant.elementType != XCUIElementTypeOther) {
      return;
    }
    CGRect curFrame = descendant.frame;
    if (CGRectEqualToRect(appFrame, curFrame)
        || curFrame.origin.x <= 0
        || curFrame.size.width >= appFrame.size.width) {
      return;
    }
    CGFloat possibleCenterX = (appFrame.size.width - curFrame.size.width) / 2;
    if (fabs(possibleCenterX - curFrame.origin.x) >= MAX_CENTER_DELTA) {
      return;
    }

    __block NSUInteger buttonsCount = 0;
    __block NSUInteger textViewsCount = 0;
    [descendant enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> innerDescendant) {
      XCUIElementType curType = innerDescendant.elementType;
      if (curType == XCUIElementTypeButton) {
        buttonsCount++;
      } else if (curType == XCUIElementTypeTextView) {
        textViewsCount++;
      }
    }];
    if (buttonsCount >= 1 && buttonsCount <= 2 && textViewsCount > 0) {
      candidate = descendant;
    }
  }];
  return candidate;
}

+ (nullable id<FBXCElementSnapshot>)fb_findAlertSnapshotInApplicationSnapshot:(id<FBXCElementSnapshot>)appSnapshot
{
  __block id<FBXCElementSnapshot> found = nil;
  [appSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil != found) {
      return;
    }
    XCUIElementType curType = descendant.elementType;
    if (curType == XCUIElementTypeAlert || curType == XCUIElementTypeSheet || curType == XCUIElementTypeScrollView) {
      found = descendant;
    }
  }];
  if (nil == found) {
    return nil;
  }

  if (found.elementType == XCUIElementTypeAlert) {
    return found;
  }

  if (found.elementType == XCUIElementTypeSheet) {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
      return found;
    }

    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    id<FBXCElementSnapshot> ancestor = found.parent;
    while (nil != ancestor) {
      if (nil != ancestor.identifier && [ancestor.identifier isEqualToString:@"PopoverDismissRegion"]) {
        return nil;
      }
      ancestor = ancestor.parent;
    }
    return found;
  }

  if (found.elementType == XCUIElementTypeScrollView) {
    id<FBXCElementSnapshot> app = [[FBXCElementSnapshotWrapper ensureWrapped:found] fb_parentMatchingType:XCUIElementTypeApplication];
    if (nil != app && [app.label isEqualToString:FB_SAFARI_APP_NAME]) {
      // Check alert presence in Safari web view
      return [self fb_findSafariAlertSnapshotInScrollView:found];
    }
  }

  return nil;
}

- (nullable id<FBXCElementSnapshot>)fb_alertSnapshot
{
  id<FBXCElementSnapshot> appSnapshot = self.fb_cachedSnapshot ?: [self fb_customSnapshot];
  if (nil == appSnapshot) {
    return nil;
  }
  return [self.class fb_findAlertSnapshotInApplicationSnapshot:appSnapshot];
}

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
  id<FBXCElementSnapshot> snapshot = candidate.fb_cachedSnapshot ?: [candidate fb_customSnapshot];
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
  id<FBXCElementSnapshot> alertSnapshot = alert.fb_cachedSnapshot ?: [alert fb_customSnapshot];

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
