/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIApplication+FBAlert.h"

#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBUtilities.h"

#define MAX_CENTER_DELTA 10.0

NSString *const FB_SAFARI_APP_NAME = @"Safari";

// The iOS 18+ limited access permission prompt (e.g. the "Select Contacts" view)
// runs in a dedicated process that is not reported by fb_activeApplications.
static NSString *const FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID = @"com.apple.ContactsUI.LimitedAccessPromptView";


@implementation XCUIApplication (FBAlert)

+ (nullable XCUIApplication *)fb_limitedAccessPromptApplication
{
  XCUIApplication *promptApp = [[XCUIApplication alloc] initWithBundleIdentifier:FB_LIMITED_ACCESS_PROMPT_BUNDLE_ID];
  return promptApp.state < XCUIApplicationStateRunningForeground ? nil : promptApp;
}

+ (nullable id<FBXCElementSnapshot>)fb_findSafariAlertSnapshotInScrollView:(id<FBXCElementSnapshot>)scrollViewSnapshot
{
  if (nil == scrollViewSnapshot) {
    return nil;
  }

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

// Resolving a query (e.g. allElementsBoundByIndex) is itself
// as expensive as taking a snapshot - it has to walk/resolve the matching
// subtree either way. So this issues exactly ONE such query, matching all
// three candidate types at once, instead of one query per type: querying
// Alert, then Sheet, then ScrollView separately would pay that cost up to
// three times over, which is worse than a single whole-app snapshot in the
// common case where no alert is present at all (the query comes back
// empty on the very first attempt). Priority is then resolved in memory
// over the (typically 0-1 element) result: an Alert always wins outright,
// a Sheet only loses to an Alert, and a ScrollView (the Safari web-alert
// case) is the last resort. Per-candidate ancestor/subtree checks (the
// iPad popover check, the Safari web-alert walk) only run for candidates
// that actually matched, not for every possible type.
- (nullable XCUIElement *)fb_alertElementWithSnapshot:(id<FBXCElementSnapshot> _Nullable * _Nullable)snapshotOut
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu,%lu}",
                            XCUIElementTypeAlert, XCUIElementTypeSheet, XCUIElementTypeScrollView];
  // allElementsBoundByAccessibilityElement resolves all matches in one
  // round trip; allElementsBoundByIndex pays one extra round trip per
  // match, costly while the target is JS-blocked inside alert() (~5s per
  // hop).
  NSArray<XCUIElement *> *candidates = [[self descendantsMatchingType:XCUIElementTypeAny]
                                        matchingPredicate:predicate].allElementsBoundByAccessibilityElement;
  if (0 == candidates.count) {
    return nil;
  }

  NSMutableArray<XCUIElement *> *sheets = [NSMutableArray array];
  NSMutableArray<XCUIElement *> *scrollViews = [NSMutableArray array];
  for (XCUIElement *candidate in candidates) {
    XCUIElementType elementType = candidate.elementType;
    if (elementType == XCUIElementTypeAlert) {
      return candidate;
    } else if (elementType == XCUIElementTypeSheet) {
      [sheets addObject:candidate];
    } else if (elementType == XCUIElementTypeScrollView) {
      [scrollViews addObject:candidate];
    }
  }

#if TARGET_OS_WATCH
  // No popover concept or UIUserInterfaceIdiom on watchOS - treat sheets like phone sheets.
  BOOL isPhone = YES;
#else
  BOOL isPhone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
#endif
  for (XCUIElement *sheet in sheets) {
    if (isPhone) {
      return sheet;
    }

    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    id<FBXCElementSnapshot> sheetSnapshot = sheet.fb_cachedSnapshot ?: [sheet fb_customSnapshot];
    BOOL isInsidePopover = NO;
    id<FBXCElementSnapshot> ancestor = sheetSnapshot.parent;
    while (nil != ancestor) {
      if (nil != ancestor.identifier && [ancestor.identifier isEqualToString:@"PopoverDismissRegion"]) {
        isInsidePopover = YES;
        break;
      }
      ancestor = ancestor.parent;
    }
    if (!isInsidePopover) {
      if (NULL != snapshotOut) {
        *snapshotOut = sheetSnapshot;
      }
      return sheet;
    }
  }

  for (XCUIElement *scrollView in scrollViews) {
    id<FBXCElementSnapshot> scrollViewSnapshot = scrollView.fb_cachedSnapshot ?: [scrollView fb_customSnapshot];
    id<FBXCElementSnapshot> app = [[FBXCElementSnapshotWrapper ensureWrapped:scrollViewSnapshot] fb_parentMatchingType:XCUIElementTypeApplication];
    if (nil == app || ![app.label isEqualToString:FB_SAFARI_APP_NAME]) {
      continue;
    }
    // Check alert presence in Safari web view
    id<FBXCElementSnapshot> safariAlertSnapshot = [self.class fb_findSafariAlertSnapshotInScrollView:scrollViewSnapshot];
    if (nil != safariAlertSnapshot) {
      // Not resolving safariAlertSnapshot to a live element here (another
      // round trip) - scrollView is already live and is a valid ancestor
      // for callers to resolve buttons/fields from later.
      if (NULL != snapshotOut) {
        *snapshotOut = safariAlertSnapshot;
      }
      return scrollView;
    }
  }

  return nil;
}

@end
