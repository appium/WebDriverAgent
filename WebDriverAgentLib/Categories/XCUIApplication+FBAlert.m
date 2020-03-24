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

#define MAX_CENTER_DELTA 20.0

@implementation XCUIApplication (FBAlert)

- (nullable XCUIElement *)fb_alertElementFromSafari
{
  XCUIElement *webView = self.webViews.fb_firstMatch;
  if (nil == webView) {
    return nil;
  }
  CGRect webViewFrame = webView.frame;
  if (!CGRectEqualToRect(webViewFrame, self.frame)) {
    // Web view frame is expected to have the same size as Safari window
    return nil;
  }
  NSDictionary *webViewRect = webView.wdRect;
  // Find the sibling of XCUIElementTypeOther covering the whole web view area,
  // which has different size and contains at least one button and one text view
  NSString *viewLocator = [NSString stringWithFormat:@"//XCUIElementTypeOther[@x=\"0\" and @y=\"0\" and @width=\"%@\" and @height=\"%@\"]/following-sibling::XCUIElementTypeOther[@x!=\"0\" and @y!=\"0\" and @width!=\"%@\" and @height!=\"%@\" and .//XCUIElementTypeButton and .//XCUIElementTypeTextView]", webViewRect[@"width"], webViewRect[@"height"], webViewRect[@"width"], webViewRect[@"height"]];
  NSArray<XCUIElement *> *matchingViews = [webView fb_descendantsMatchingXPathQuery:viewLocator
                                                        shouldReturnAfterFirstMatch:YES];
  if (matchingViews.count < 1) {
    return nil;
  }
  CGRect possibleAlertFrame = matchingViews.firstObject.frame;
  CGFloat possibleCenterX = (webViewFrame.size.width - possibleAlertFrame.size.width) / 2;
  CGFloat possibleCenterY = (webViewFrame.size.height - possibleAlertFrame.size.height) / 2;
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
