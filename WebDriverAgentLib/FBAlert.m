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
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"


@interface FBAlert ()
@property (nonatomic, strong) XCUIApplication *application;
@property (nonatomic, nullable) XCUIElement *cachedAlertElement;
@property (nonatomic) BOOL hasCachedAlertElement;
@property (nonatomic, nullable) id<FBXCElementSnapshot> cachedAlertSnapshot;
@property (nonatomic) BOOL hasCachedAlertSnapshot;
@end

@implementation FBAlert

+ (instancetype)alertWithApplication:(XCUIApplication *)application
{
  FBAlert *alert = [FBAlert new];
  alert.application = application;
  return alert;
}

// Resolved (and, if found, snapshotted) at most once per instance and then
// reused for every subsequent call - see FBAlert.h. This is what makes an
// isPresent check followed by an action (the FBAlertsMonitor/FBSession
// auto-accept flow) act on the exact same alert it just observed, instead of
// re-resolving against a UI that may have changed in between.
- (nullable XCUIElement *)alertElement
{
  if (!self.hasCachedAlertElement) {
    id<FBXCElementSnapshot> snapshot = nil;
    self.cachedAlertElement = [self alertElementFromApplication:&snapshot];
    self.hasCachedAlertElement = YES;
    if (nil != snapshot) {
      self.cachedAlertSnapshot = snapshot;
      self.hasCachedAlertSnapshot = YES;
    }
  }
  return self.cachedAlertElement;
}

// The alert element's own subtree snapshot, taken once. All read-only
// accessors (text, buttonLabels) and all element lookups (buttons, input
// fields) work off this single snapshot in memory - only tapping/typing into
// a specific already-located element pays for one more, narrowly targeted
// accessibility round trip (see XCUIApplication.fb_elementForSnapshot:underElement:).
// fb_cachedSnapshot is tried before fb_customSnapshot: it can reconstruct
// the element's snapshot from the detection query's already-fetched
// rootElementSnapshot without a further round trip (verified empirically -
// see XCUIApplication+FBAlert.m).
- (nullable id<FBXCElementSnapshot>)alertSnapshot
{
  if (!self.hasCachedAlertSnapshot) {
    XCUIElement *alertElement = self.alertElement;
    self.cachedAlertSnapshot = nil == alertElement
      ? nil
      : (alertElement.fb_cachedSnapshot ?: [alertElement fb_customSnapshot]);
    self.hasCachedAlertSnapshot = YES;
  }
  return self.cachedAlertSnapshot;
}

- (BOOL)isPresent
{
  return nil != self.alertElement;
}

+ (NSArray<id<FBXCElementSnapshot>> *)fb_buttonSnapshotsInSnapshot:(id<FBXCElementSnapshot>)snapshot
{
  NSMutableArray<id<FBXCElementSnapshot>> *buttons = [NSMutableArray array];
  [snapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (descendant.elementType == XCUIElementTypeButton) {
      [buttons addObject:descendant];
    }
  }];
  return buttons.copy;
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
  id<FBXCElementSnapshot> snapshot = self.alertSnapshot;
  if (nil == snapshot) {
    return nil;
  }

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
  XCUIElement *alertElement = self.alertElement;
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil == alertElement || nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  NSMutableArray<id<FBXCElementSnapshot>> *dstFieldSnapshots = [NSMutableArray array];
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    XCUIElementType elementType = descendant.elementType;
    if (elementType == XCUIElementTypeTextField || elementType == XCUIElementTypeSecureTextField) {
      [dstFieldSnapshots addObject:descendant];
    }
  }];
  if (dstFieldSnapshots.count > 1) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"The alert contains more than one input field"];
  }
  id<FBXCElementSnapshot> dstFieldSnapshot = dstFieldSnapshots.firstObject;
  if (nil == dstFieldSnapshot) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"The alert contains no input fields"];
  }
  XCUIElement *dstField = [XCUIApplication fb_elementForSnapshot:dstFieldSnapshot
                                                      underElement:alertElement];
  if (nil == dstField) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"Failed to resolve the input field element"];
  }
  NSError *error;
  // dstField was just resolved via a live query in fb_elementForSnapshot:underElement:
  // above, so its cached snapshot can be safely reconstructed in memory
  // instead of paying for a fresh round trip.
  id<FBXCElementSnapshot> snapshot = dstField.fb_cachedSnapshot ?: [dstField fb_standardSnapshot];
  if (![dstField fb_typeText:text
                  shouldClear:YES
                    frequency:FBConfiguration.sharedInstance.maxTypingFrequency
                     snapshot:snapshot
                        error:&error]) {
    [self fb_raiseSetTextFailedExceptionWithReason:error.description];
  }
}

- (NSArray *)buttonLabels
{
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil == alertSnapshot) {
    return nil;
  }

  NSMutableArray<NSString *> *labels = [NSMutableArray array];
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
  XCUIElement *alertElement = self.alertElement;
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil == alertElement || nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *acceptButton = nil;
  if (FBConfiguration.sharedInstance.acceptAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      acceptButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.sharedInstance.acceptAlertButtonSelector
                                           shouldReturnAfterFirstMatch:YES] firstObject];
    } @catch (NSException *ex) {
      errorReason = ex.reason;
    }
    if (nil == acceptButton) {
      [FBLogger logFmt:@"Cannot find any match for Accept alert button using the class chain selector '%@'",
       FBConfiguration.sharedInstance.acceptAlertButtonSelector];
      if (nil != errorReason) {
        [FBLogger logFmt:@"Original error: %@", errorReason];
      }
      [FBLogger log:@"Will fallback to the default button location algorithm"];
   }
  }
  if (nil == acceptButton) {
    // buttonSnapshotsInSnapshot's tree-order walk doesn't always match a
    // live query's ordering: on the system location-permission alert (iOS
    // 17.5, confirmed via manual testing), that mismatch put a
    // non-dismissing "Precise: On/Off" toggle first, so accept/dismiss
    // silently tapped the wrong control and left the alert on screen. Not
    // reproduced on iOS 18+, so keep the cheaper snapshot walk there and
    // only pay for a live query below iOS 18.
    if (@available(iOS 18.0, *)) {
      NSArray<id<FBXCElementSnapshot>> *buttonSnapshots = [self.class fb_buttonSnapshotsInSnapshot:alertSnapshot];
      id<FBXCElementSnapshot> chosenSnapshot = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
        ? buttonSnapshots.lastObject
        : buttonSnapshots.firstObject;
      if (nil != chosenSnapshot) {
        acceptButton = [XCUIApplication fb_elementForSnapshot:chosenSnapshot underElement:alertElement];
      }
    } else {
      NSArray<XCUIElement *> *buttons = [alertElement.fb_query
                                         descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
      acceptButton = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
        ? buttons.lastObject
        : buttons.firstObject;
    }
  }
  if (nil == acceptButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find accept button for alert: %@", alertElement]];
  }
  [acceptButton tap];
}

- (void)dismiss
{
  XCUIElement *alertElement = self.alertElement;
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil == alertElement || nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *dismissButton = nil;
  if (FBConfiguration.sharedInstance.dismissAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      dismissButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.sharedInstance.dismissAlertButtonSelector
                                            shouldReturnAfterFirstMatch:YES] firstObject];
    } @catch (NSException *ex) {
      errorReason = ex.reason;
    }
    if (nil == dismissButton) {
      [FBLogger logFmt:@"Cannot find any match for Dismiss alert button using the class chain selector '%@'",
       FBConfiguration.sharedInstance.dismissAlertButtonSelector];
      if (nil != errorReason) {
        [FBLogger logFmt:@"Original error: %@", errorReason];
      }
      [FBLogger log:@"Will fallback to the default button location algorithm"];
    }
  }
  if (nil == dismissButton) {
    // See the matching comment in accept.
    if (@available(iOS 18.0, *)) {
      NSArray<id<FBXCElementSnapshot>> *buttonSnapshots = [self.class fb_buttonSnapshotsInSnapshot:alertSnapshot];
      id<FBXCElementSnapshot> chosenSnapshot = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
        ? buttonSnapshots.firstObject
        : buttonSnapshots.lastObject;
      if (nil != chosenSnapshot) {
        dismissButton = [XCUIApplication fb_elementForSnapshot:chosenSnapshot underElement:alertElement];
      }
    } else {
      NSArray<XCUIElement *> *buttons = [alertElement.fb_query
                                         descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
      dismissButton = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
        ? buttons.firstObject
        : buttons.lastObject;
    }
  }

  if (nil == dismissButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find dismiss button for alert: %@", alertElement]];
  }
  [dismissButton tap];
}

- (void)clickAlertButton:(NSString *)label
{
  XCUIElement *alertElement = self.alertElement;
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil == alertElement || nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  __block id<FBXCElementSnapshot> matchedSnapshot = nil;
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil != matchedSnapshot || descendant.elementType != XCUIElementTypeButton) {
      return;
    }
    NSString *btnLabel = [FBXCElementSnapshotWrapper ensureWrapped:descendant].wdLabel;
    if (nil != btnLabel && [btnLabel isEqualToString:label]) {
      matchedSnapshot = descendant;
    }
  }];
  XCUIElement *requestedButton = nil == matchedSnapshot
    ? nil
    : [XCUIApplication fb_elementForSnapshot:matchedSnapshot underElement:alertElement];
  if (!requestedButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find button with label '%@' for alert: %@", label, alertElement]];
  }
  [requestedButton tap];
}

- (void)clickElementMatchingClassChain:(NSString *)classChain
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  // For a Safari web alert, alertElement is the containing scrollView, not
  // the alert's own div (see fb_alertElementWithSnapshot:), so a classChain
  // query from it could also match unrelated page content. Constrain
  // matches to descendants of alertSnapshot by uid when available.
  NSSet<NSString *> *alertSnapshotUids = nil;
  id<FBXCElementSnapshot> alertSnapshot = self.alertSnapshot;
  if (nil != alertSnapshot) {
    NSMutableSet<NSString *> *uids = [NSMutableSet set];
    NSString *rootUid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:alertSnapshot];
    if (nil != rootUid) {
      [uids addObject:rootUid];
    }
    [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
      NSString *uid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:descendant];
      if (nil != uid) {
        [uids addObject:uid];
      }
    }];
    alertSnapshotUids = uids;
  }

  NSArray<XCUIElement *> *matches = nil;
  @try {
    matches = [alertElement fb_descendantsMatchingClassChain:classChain
                                  shouldReturnAfterFirstMatch:NO];
  } @catch (NSException *ex) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to match class chain selector '%@' for alert: %@. Original error: %@", classChain, alertElement, ex.reason]];
  }
  XCUIElement *matchedElement = nil;
  for (XCUIElement *match in matches) {
    NSString *matchUid = match.fb_uid;
    if (nil == alertSnapshotUids || (nil != matchUid && [alertSnapshotUids containsObject:matchUid])) {
      matchedElement = match;
      break;
    }
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
// queries (see XCUIApplication.fb_alertElementWithSnapshot:) instead of
// snapshotting and walking the whole application tree - the cost stays
// proportional to the number of alert-shaped elements rather than the
// size/depth of the app, which matters a lot for deeply nested view
// hierarchies. Only ever invoked once per instance, by the alertElement
// getter above, which caches both the element and (if one comes back) the
// snapshot obtained as a side effect of resolving it.
- (nullable XCUIElement *)alertElementFromApplication:(id<FBXCElementSnapshot> _Nullable *)snapshotOut
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
      XCUIElement *element = [candidate fb_alertElementWithSnapshot:snapshotOut];
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
