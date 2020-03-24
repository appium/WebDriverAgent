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
  // Find the first XCUIElementTypeOther which is contained by the web view
  // and is aligned to the center of the screen
  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(XCUIElement *element, NSDictionary *bindings) {
    CGRect curFrame = element.frame;
    if (!CGRectContainsRect(webViewFrame, curFrame) || CGRectEqualToRect(webViewFrame, curFrame)) {
      return NO;
    }
    CGFloat possibleCenterX = (webViewFrame.size.width - curFrame.size.width) / 2;
    CGFloat possibleCenterY = (webViewFrame.size.height - curFrame.size.height) / 2;
    if (fabs(possibleCenterX - curFrame.origin.x) < MAX_CENTER_DELTA
        && fabs(possibleCenterY - curFrame.origin.y) < MAX_CENTER_DELTA) {
      return YES;
    }
    return NO;
  }];
  XCUIElement *matchingView = [[webView descendantsMatchingType:XCUIElementTypeOther]
                               matchingPredicate:predicate].fb_firstMatch;
  if (nil == matchingView) {
    [FBLogger log:@">>> Found no views matching to the predicate"];
    return nil;
  }
  [FBLogger log:@">>> Found a view matching to the predicate"];
  // ...and contains one or two buttons and at least one text view
  NSUInteger buttonsCount = matchingView.buttons.count;
  NSUInteger textViewsCount = matchingView.textViews.count;
  [FBLogger logFmt:@">>> buttonsCount: %@, textViewsCount: %@", @(buttonsCount), @(textViewsCount)];
  if (buttonsCount < 1 || buttonsCount > 2 || textViewsCount < 1) {
    return nil;
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
