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
#import "FBMacros.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUID.h"
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
  return nil != [self alertSnapshotFromApplication:NULL];
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
  id<FBXCElementSnapshot> snapshot = [self alertSnapshotFromApplication:NULL];
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
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
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
  if (0 == dstFieldSnapshots.count) {
    [self fb_raiseSetTextFailedExceptionWithReason:@"The alert contains no input fields"];
  }
  XCUIElement *dstField = [self elementForSnapshot:dstFieldSnapshots.firstObject inApplication:snapshotApplication];
  if (nil == dstField) {
    [self fb_raiseNotPresentException];
  }
  NSError *error;
  if (![dstField fb_typeText:text shouldClear:YES error:&error]) {
    [self fb_raiseSetTextFailedExceptionWithReason:error.description];
  }
}

- (NSArray *)buttonLabels
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return nil;
  }

  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  if (@available(iOS 18.0, *)) {
    [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
      if (descendant.elementType != XCUIElementTypeButton) {
        return;
      }
      NSString *label = [FBXCElementSnapshotWrapper ensureWrapped:descendant].wdLabel;
      if (nil != label) {
        [labels addObject:[NSString stringWithFormat:@"%@", label]];
      }
    }];
    if (labels.count > 0) {
      return labels.copy;
    }
  }

  // See fb_buttonInAlertSnapshot:inApplication:preferLast: for why this
  // falls back to a live query on iOS < 18, or when the snapshot walk
  // finds nothing on iOS 18+.
  XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:snapshotApplication];
  if (nil == alertElement) {
    return labels.copy;
  }
  NSArray<XCUIElement *> *liveButtons = [alertElement descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
  for (XCUIElement *button in liveButtons) {
    NSString *label = button.label;
    if (nil != label) {
      [labels addObject:label];
    }
  }
  return labels.copy;
}

+ (NSArray<id<FBXCElementSnapshot>> *)buttonSnapshotsInAlertSnapshot:(id<FBXCElementSnapshot>)alertSnapshot
{
  NSMutableArray<id<FBXCElementSnapshot>> *buttons = [NSMutableArray array];
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (descendant.elementType == XCUIElementTypeButton) {
      [buttons addObject:descendant];
    }
  }];
  return buttons;
}

// On iOS < 18, some system alerts (e.g. certain permission prompts) nest
// their buttons deep enough that a single snapshot taken from the
// application root exceeds FBConfiguration.snapshotMaxDepth before it
// reaches them, even though the same snapshot easily reaches the alert's
// own type/text near the top of the tree - and critically, sibling buttons
// can sit at different depths, so the snapshot walk there is not simply
// "empty or complete": it can silently return a partial, wrong button set
// instead of failing cleanly. That is unsafe for choosing which button to
// tap, so iOS < 18 always resolves the alert element live and queries
// buttons from it, which gives that query its own fresh depth budget
// starting from the alert itself instead of the application root -
// matching how the previous XCUIElementQuery-based implementation
// behaved. On iOS 18+, where this has been verified safe, the cheap
// in-memory snapshot walk is tried first and only falls back to the live
// query if it finds no buttons at all.
- (nullable XCUIElement *)fb_buttonInAlertSnapshot:(id<FBXCElementSnapshot>)alertSnapshot
                                      inApplication:(XCUIApplication *)application
                                         preferLast:(BOOL)preferLast
{
  if (@available(iOS 18.0, *)) {
    NSArray<id<FBXCElementSnapshot>> *buttons = [self.class buttonSnapshotsInAlertSnapshot:alertSnapshot];
    id<FBXCElementSnapshot> buttonSnapshot = preferLast ? buttons.lastObject : buttons.firstObject;
    if (nil != buttonSnapshot) {
      return [self elementForSnapshot:buttonSnapshot inApplication:application];
    }
  }

  XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:application];
  if (nil == alertElement) {
    return nil;
  }
  NSArray<XCUIElement *> *liveButtons = [alertElement descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
  return preferLast ? liveButtons.lastObject : liveButtons.firstObject;
}

// See fb_buttonInAlertSnapshot:inApplication:preferLast: for why this
// branches on iOS version.
- (nullable XCUIElement *)fb_buttonInAlertSnapshot:(id<FBXCElementSnapshot>)alertSnapshot
                                      inApplication:(XCUIApplication *)application
                                      matchingLabel:(NSString *)label
{
  if (@available(iOS 18.0, *)) {
    __block id<FBXCElementSnapshot> matchedButtonSnapshot = nil;
    [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
      if (nil != matchedButtonSnapshot || descendant.elementType != XCUIElementTypeButton) {
        return;
      }
      if ([[FBXCElementSnapshotWrapper ensureWrapped:descendant].wdLabel isEqualToString:label]) {
        matchedButtonSnapshot = descendant;
      }
    }];
    if (nil != matchedButtonSnapshot) {
      return [self elementForSnapshot:matchedButtonSnapshot inApplication:application];
    }
  }

  XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:application];
  if (nil == alertElement) {
    return nil;
  }
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
  return [[alertElement descendantsMatchingType:XCUIElementTypeButton]
          matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
}

- (void)accept
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *acceptButton = nil;
  if (FBConfiguration.acceptAlertButtonSelector.length) {
    XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:snapshotApplication];
    NSString *errorReason = nil;
    if (nil != alertElement) {
      @try {
        acceptButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.acceptAlertButtonSelector
                                           shouldReturnAfterFirstMatch:YES] firstObject];
      } @catch (NSException *ex) {
        errorReason = ex.reason;
      }
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
    BOOL preferLast = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot]);
    acceptButton = [self fb_buttonInAlertSnapshot:alertSnapshot inApplication:snapshotApplication preferLast:preferLast];
  }
  if (nil == acceptButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find accept button for alert: %@", alertSnapshot]];
  }
  [acceptButton tap];
}

- (void)dismiss
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *dismissButton = nil;
  if (FBConfiguration.dismissAlertButtonSelector.length) {
    XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:snapshotApplication];
    NSString *errorReason = nil;
    if (nil != alertElement) {
      @try {
        dismissButton = [[alertElement fb_descendantsMatchingClassChain:FBConfiguration.dismissAlertButtonSelector
                                            shouldReturnAfterFirstMatch:YES] firstObject];
      } @catch (NSException *ex) {
        errorReason = ex.reason;
      }
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
    BOOL preferLast = !(alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot]);
    dismissButton = [self fb_buttonInAlertSnapshot:alertSnapshot inApplication:snapshotApplication preferLast:preferLast];
  }

  if (nil == dismissButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find dismiss button for alert: %@", alertSnapshot]];
  }
  [dismissButton tap];
}

- (void)clickAlertButton:(NSString *)label
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *requestedButton = [self fb_buttonInAlertSnapshot:alertSnapshot
                                                    inApplication:snapshotApplication
                                                    matchingLabel:label];
  if (!requestedButton) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find button with label '%@' for alert: %@", label, alertSnapshot]];
  }
  [requestedButton tap];
}

- (void)clickElementMatchingClassChain:(NSString *)classChain
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    [self fb_raiseNotPresentException];
  }
  XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:snapshotApplication];
  if (nil == alertElement) {
    [self fb_raiseNotPresentException];
  }

  XCUIElement *matchedElement = nil;
  @try {
    matchedElement = [[alertElement fb_descendantsMatchingClassChain:classChain
                                           shouldReturnAfterFirstMatch:YES] firstObject];
  } @catch (NSException *ex) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to match class chain selector '%@' for alert: %@. Original error: %@", classChain, alertSnapshot, ex.reason]];
  }
  if (nil == matchedElement) {
    [self fb_raiseActionFailedExceptionWithReason:
     [NSString stringWithFormat:@"Failed to find any element matching class chain selector '%@' for alert: %@", classChain, alertSnapshot]];
  }
  [matchedElement tap];
}

// Single source of truth for alert detection: takes one upfront snapshot per
// candidate application (systemApp, then self.application if different, then
// the iOS 18+ limited access prompt app) and walks it purely in-memory to
// find an alert-shaped descendant - no accessibility round trips beyond the
// snapshot fetch itself. Every public method funnels through this instead of
// the old XCUIElementQuery-based element search, which could cost several
// discrete round trips (one per query stage, worse yet for Safari's nested
// web-alert lookup). Returns the application the snapshot was found in via
// `matchedApplication`, since that is the anchor elementForSnapshot:
// needs - pass NULL if the caller only needs the snapshot.
- (nullable id<FBXCElementSnapshot>)alertSnapshotFromApplication:(XCUIApplication * _Nullable * _Nullable)matchedApplication
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
      id<FBXCElementSnapshot> snapshot = candidate.fb_alertSnapshot;
      if (nil != snapshot) {
        if (NULL != matchedApplication) {
          *matchedApplication = candidate;
        }
        return snapshot;
      }
    }
  } @catch (NSException *) {
    return nil;
  }
  return nil;
}

// Resolves the live, tappable element that corresponds to an already-known
// snapshot by matching on its stable uid, instead of re-running a fresh
// attribute/type-based query - a single targeted accessibility round trip
// regardless of how deep the snapshot sits in the tree.
- (nullable XCUIElement *)elementForSnapshot:(id<FBXCElementSnapshot>)snapshot
                                inApplication:(XCUIApplication *)application
{
  NSString *uid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:snapshot];
  if (nil == uid) {
    return nil;
  }
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@",
                             FBStringify(FBXCElementSnapshotWrapper, fb_uid), uid];
  @try {
    return [[application.fb_query descendantsMatchingType:XCUIElementTypeAny]
            matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
  } @catch (NSException *) {
    return nil;
  }
}

@end
