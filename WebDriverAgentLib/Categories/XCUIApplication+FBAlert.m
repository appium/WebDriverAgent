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
#import "XCUIElement+FBFind.h"
#import "FBPredicate.h"
#import "FBLogger.h"

#define MAX_CENTER_DELTA 20.0

@implementation XCUIApplication (FBAlert)

- (nullable XCUIElement *)fb_alertElementFromSafari
{
  XCUIElement *webView = self.webViews.fb_firstMatch;
  if (nil == webView) {
    [FBLogger log:@">>> Found no web views"];
    return nil;
  }
  [FBLogger log:@">>> Found a web view"];
  CGRect webViewFrame = webView.frame;
  if (!CGRectEqualToRect(webViewFrame, self.frame)) {
    [FBLogger log:@">>> Web view frame does not match to the app frame"];
    // Web view frame is expected to have the same size as Safari window
    return nil;
  }
  [FBLogger log:@">>> Web view frame matches to the app frame"];
  NSDictionary *webViewRect = webView.wdRect;
  // Find the first XCUIElementTypeOther which has different size
  NSString *viewLocator = [NSString stringWithFormat:@"type == 'XCUIElementTypeOther' AND rect.x != '0' AND rect.y != '0' AND rect.width != '%@' AND rect.height != '%@'", webViewRect[@"width"], webViewRect[@"height"]];
  NSPredicate *predicate = [FBPredicate predicateWithFormat:viewLocator];
  NSArray<XCUIElement *> *matchingViews = [webView fb_descendantsMatchingPredicate:predicate
                                                       shouldReturnAfterFirstMatch:YES];
  if (matchingViews.count < 1) {
    [FBLogger logFmt:@">>> Found no views matching to \"%@\" predicate", viewLocator];
    return nil;
  }
  [FBLogger logFmt:@">>> Found a view matching to \"%@\" predicate", viewLocator];
  // ...and contains one or two buttons and at least one text view
  NSUInteger buttonsCount = matchingViews.firstObject.buttons.count;
  NSUInteger textViewsCount = matchingViews.firstObject.textViews.count;
  [FBLogger logFmt:@">>> buttonsCount: %@, textViewsCount: %@", @(buttonsCount), @(textViewsCount)];
  if (buttonsCount < 1 || buttonsCount > 2 || textViewsCount < 1) {
    return nil;
  }
  CGRect possibleAlertFrame = matchingViews.firstObject.frame;
  CGFloat possibleCenterX = (webViewFrame.size.width - possibleAlertFrame.size.width) / 2;
  CGFloat possibleCenterY = (webViewFrame.size.height - possibleAlertFrame.size.height) / 2;
  [FBLogger logFmt:@">>> possibleAlertFrame: %@, webViewFrame: %@", [NSValue valueWithCGRect:possibleAlertFrame], [NSValue valueWithCGRect:webViewFrame]];
  if (fabs(possibleCenterX - possibleAlertFrame.origin.x) < MAX_CENTER_DELTA
      && fabs(possibleCenterY - possibleAlertFrame.origin.y) < MAX_CENTER_DELTA) {
    // Assume this is an alert if it is aligned to the center of the screen
    return matchingViews.firstObject;
  }
  return nil;
}

- (XCUIElement *)fb_alertElement
{
  XCUIElement *alert = self.alerts.fb_firstMatch;
  if (nil != alert) {
    return alert;
  }

  alert = self.sheets.fb_firstMatch;
  if (nil != alert) {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
      return alert;
    }
    // In case of iPad we want to check if sheet isn't contained by popover.
    // In that case we ignore it.
    NSPredicate *predicateString = [NSPredicate predicateWithFormat:@"identifier == 'PopoverDismissRegion'"];
    XCUIElementQuery *query = [[self.fb_query descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:predicateString];
    if (!query.fb_firstMatch) {
      return alert;
    }
  }

  // Check alert presence in Safari web view
  if ([self.wdName isEqualToString:@"Safari"]) {
    return [self fb_alertElementFromSafari];
  }

  return nil;
}

@end
