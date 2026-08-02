/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAlert.h"

#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"


@interface FBAlert ()
@property (nonatomic, strong) XCUIApplication *application;
@end

@implementation FBAlert

+ (instancetype)alertWithApplication:(XCUIApplication *)application
{
  FBAlert *alert = [FBAlert new];
  alert.application = application;
  return alert;
}

- (BOOL)isPresent
{
  @try {
    return nil != [self alertElementFromApplication];
  } @catch (NSException *) {
    return NO;
  }
}

- (void)fb_raiseNotPresentException __attribute__((noreturn))
{
  @throw [NSException exceptionWithName:FBAlertNotPresentException
                                  reason:@"No alert is open"
                                userInfo:nil];
}

- (void)fb_raiseActionFailedExceptionWithReason:(NSString *)reason __attribute__((noreturn))
{
  @throw [NSException exceptionWithName:FBAlertActionFailedException
                                  reason:reason
                                userInfo:nil];
}

- (void)fb_raiseSetTextFailedExceptionWithReason:(NSString *)reason __attribute__((noreturn))
{
  @throw [NSException exceptionWithName:FBAlertSetTextFailedException
                                  reason:reason
                                userInfo:nil];
}

+ (BOOL)isSafariWebAlertWithSnapshot:(id<FBXCElementSnapshot>)snapshot
{
  if (snapshot.elementType != XCUIElementTypeOther) {
    return NO;
  }

  FBXCElementSnapshotWrapper *snapshotWrapper = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  id<FBXCElementSnapshot> application = [snapshotWrapper fb_parentMatchingType:XCUIElementTypeApplication];
  return nil != application && [application.label isEqualToString:FB_SAFARI_APP_NAME];
}

- (NSString *)text
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    return nil;
  }

  id<FBXCElementSnapshot> snapshot = alertElement.lastSnapshot ?: [alertElement fb_customSnapshot];
  NSMutableArray<NSString *> *resultText = [NSMutableArray array];
  BOOL isSafariAlert = [self.class isSafariWebAlertWithSnapshot:snapshot];
  [snapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    XCUIElementType elementType = descendant.elementType;
    if (!(elementType == XCUIElementTypeTextView || elementType == XCUIElementTypeStaticText)) {
      return;
    }

    FBXCElementSnapshotWrapper *descendantWrapper = [FBXCElementSnapshotWrapper ensureWrapped:descendant];
    if (elementType == XCUIElementTypeStaticText
        && nil != [descendantWrapper fb_parentMatchingType:XCUIElementTypeButton]) {
      return;
    }

    NSString *text = descendantWrapper.wdLabel ?: descendantWrapper.wdValue;
    if (isSafariAlert && nil != descendant.parent) {
      FBXCElementSnapshotWrapper *descendantParentWrapper = [FBXCElementSnapshotWrapper ensureWrapped:descendant.parent];
      NSString *parentText = descendantParentWrapper.wdLabel ?: descendantParentWrapper.wdValue;
      if ([parentText isEqualToString:text]) {
        // Avoid duplicated texts on Safari alerts
        return;
      }
    }

    if (nil != text) {
      [resultText addObject:[NSString stringWithFormat:@"%@", text]];
    }
  }];
  return [resultText componentsJoinedByString:@"\n"];
}

- (void)typeText:(NSString *)text
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  NSPredicate *textCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu}",
                                          XCUIElementTypeTextField, XCUIElementTypeSecureTextField];
  NSArray<XCUIElement *> *dstFields = [[alertElement descendantsMatchingType:XCUIElementTypeAny]
                                       matchingPredicate:textCollectorPredicate].allElementsBoundByIndex;
  if (dstFields.count > 1) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"The alert contains more than one input field"];
  }
  if (0 == dstFields.count) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"The alert contains no input fields"];
  }
  NSError *error;
  if (![dstFields.firstObject fb_typeText:text shouldClear:YES error:&error]) {
    [self fb_raiseSetTextFailedExceptionWithReason:error.description];
  }
}

- (NSArray *)buttonLabels
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    return nil;
  }

  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  id<FBXCElementSnapshot> alertSnapshot = alertElement.lastSnapshot ?: [alertElement fb_customSnapshot];
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (descendant.elementType != XCUIElementTypeButton) {
      return;
    }
    NSString *label = [FBXCElementSnapshotWrapper ensureWrapped:descendant].wdLabel;
    if (nil != label) {
      [labels addObject:[NSString stringWithFormat:@"%@", label]];
    }
  }];
  return labels.copy;
}

- (void)accept
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  id<FBXCElementSnapshot> alertSnapshot = alertElement.lastSnapshot ?: [alertElement fb_customSnapshot];
  XCUIElement *acceptButton = nil;
  if (FBConfiguration.acceptAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      acceptButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.acceptAlertButtonSelector
                                           shouldReturnAfterFirstMatch:YES] firstObject];
    } @catch (NSException *ex) {
      errorReason = ex.reason;
    }
    if (nil == acceptButton) {
      [FBLogger logFmt:@"Cannot find any match for Accept alert button using the class chain selector '%@'",
       FBConfiguration.acceptAlertButtonSelector];
      if (nil != errorReason) {
        [FBLogger logFmt:@"Original error: %@", errorReason];
      }
      [FBLogger log:@"Will fallback to the default button location algorithm"];
   }
  }
  if (nil == acceptButton) {
    NSArray<XCUIElement *> *buttons = [alertElement.fb_query
                                        descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
    acceptButton = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
      ? buttons.lastObject
      : buttons.firstObject;
  }
  if (nil == acceptButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find accept button for alert: %@", alertElement]];
  }
  [acceptButton tap];
}

- (void)dismiss
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  id<FBXCElementSnapshot> alertSnapshot = alertElement.lastSnapshot ?: [alertElement fb_customSnapshot];
  XCUIElement *dismissButton = nil;
  if (FBConfiguration.dismissAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      dismissButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.dismissAlertButtonSelector
                                            shouldReturnAfterFirstMatch:YES] firstObject];
    } @catch (NSException *ex) {
      errorReason = ex.reason;
    }
    if (nil == dismissButton) {
      [FBLogger logFmt:@"Cannot find any match for Dismiss alert button using the class chain selector '%@'",
       FBConfiguration.dismissAlertButtonSelector];
      if (nil != errorReason) {
        [FBLogger logFmt:@"Original error: %@", errorReason];
      }
      [FBLogger log:@"Will fallback to the default button location algorithm"];
    }
  }
  if (nil == dismissButton) {
    NSArray<XCUIElement *> *buttons = [alertElement.fb_query
                                        descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
    dismissButton = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
      ? buttons.firstObject
      : buttons.lastObject;
  }

  if (nil == dismissButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find dismiss button for alert: %@", alertElement]];
  }
  [dismissButton tap];
}

- (void)clickAlertButton:(NSString *)label
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
  XCUIElement *requestedButton = [[alertElement descendantsMatchingType:XCUIElementTypeButton]
                                  matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
  if (!requestedButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find button with label '%@' for alert: %@", label, alertElement]];
  }
  [requestedButton tap];
}

- (void)clickElementMatchingClassChain:(NSString *)classChain
{
  XCUIElement *alertElement = [self alertElementFromApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *matchedElement = nil;
  @try {
    matchedElement = [[alertElement fb_descendantsMatchingClassChain:classChain
                                           shouldReturnAfterFirstMatch:YES] firstObject];
  } @catch (NSException *ex) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to match class chain selector '%@' for alert: %@. Original error: %@", classChain, alertElement, ex.reason]];
  }
  if (nil == matchedElement) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find any element matching class chain selector '%@' for alert: %@", classChain, alertElement]];
  }
  [matchedElement tap];
}

// Single source of truth for alert detection: checks each candidate
// application (systemApp, then self.application if different, then the iOS
// 18+ limited access prompt app) via targeted, predicate-filtered live
// queries (see XCUIApplication.fb_alertElement) instead of snapshotting and
// walking the whole application tree - the cost stays proportional to the
// number of alert-shaped elements rather than the size/depth of the app,
// which matters a lot for deeply nested view hierarchies. Every public
// method funnels through this. No caching: each call re-resolves fresh so
// a stale/replaced alert element is never reused across calls.
- (nullable XCUIElement *)alertElementFromApplication
{
  @try {
    XCUIApplication *systemApp = XCUIApplication.fb_systemApplication;
    NSMutableArray<XCUIApplication *> *candidates = [NSMutableArray arrayWithObject:systemApp];
    if (![systemApp fb_isSameAppAs:self.application]) {
      [candidates addObject:self.application];
    }
    XCUIApplication *promptApp = XCUIApplication.fb_limitedAccessPromptApplication;
    if (nil != promptApp) {
      [candidates addObject:promptApp];
    }
    for (XCUIApplication *candidate in candidates) {
      XCUIElement *element = candidate.fb_alertElement;
      if (nil != element) {
        return element;
      }
    }
  } @catch (NSException *) {
    return nil;
  }
  return nil;
}

@end
