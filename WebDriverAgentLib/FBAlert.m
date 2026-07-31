/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAlert.h"

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
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

- (BOOL)notPresentWithError:(NSError **)error
{
  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"No alert is open"]
          buildError:error];
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

- (BOOL)typeText:(NSString *)text error:(NSError **)error
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
  }

  NSMutableArray<id<FBXCElementSnapshot>> *dstFieldSnapshots = [NSMutableArray array];
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    XCUIElementType elementType = descendant.elementType;
    if (elementType == XCUIElementTypeTextField || elementType == XCUIElementTypeSecureTextField) {
      [dstFieldSnapshots addObject:descendant];
    }
  }];
  if (dstFieldSnapshots.count > 1) {
    return [[[FBErrorBuilder builder]
      withDescriptionFormat:@"The alert contains more than one input field"]
     buildError:error];
  }
  if (0 == dstFieldSnapshots.count) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The alert contains no input fields"]
            buildError:error];
  }
  XCUIElement *dstField = [self elementForSnapshot:dstFieldSnapshots.firstObject inApplication:snapshotApplication];
  if (nil == dstField) {
    return [self notPresentWithError:error];
  }
  return [dstField fb_typeText:text
                    shouldClear:YES
                          error:error];
}

- (NSArray *)buttonLabels
{
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:NULL];
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

- (BOOL)acceptWithError:(NSError **)error
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
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
    NSArray<id<FBXCElementSnapshot>> *buttons = [self.class buttonSnapshotsInAlertSnapshot:alertSnapshot];
    id<FBXCElementSnapshot> acceptButtonSnapshot = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
      ? buttons.lastObject
      : buttons.firstObject;
    if (nil != acceptButtonSnapshot) {
      acceptButton = [self elementForSnapshot:acceptButtonSnapshot inApplication:snapshotApplication];
    }
  }
  if (nil == acceptButton) {
    return [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find accept button for alert: %@", alertSnapshot]
       buildError:error];
  }
  [acceptButton tap];
  return YES;
}

- (BOOL)dismissWithError:(NSError **)error
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
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
    NSArray<id<FBXCElementSnapshot>> *buttons = [self.class buttonSnapshotsInAlertSnapshot:alertSnapshot];
    id<FBXCElementSnapshot> dismissButtonSnapshot = (alertSnapshot.elementType == XCUIElementTypeAlert || [self.class isSafariWebAlertWithSnapshot:alertSnapshot])
      ? buttons.firstObject
      : buttons.lastObject;
    if (nil != dismissButtonSnapshot) {
      dismissButton = [self elementForSnapshot:dismissButtonSnapshot inApplication:snapshotApplication];
    }
  }

  if (nil == dismissButton) {
    return [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find dismiss button for alert: %@", alertSnapshot]
            buildError:error];
  }
  [dismissButton tap];
  return YES;
}

- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
  }

  __block id<FBXCElementSnapshot> matchedButtonSnapshot = nil;
  [alertSnapshot enumerateDescendantsUsingBlock:^(id<FBXCElementSnapshot> descendant) {
    if (nil != matchedButtonSnapshot || descendant.elementType != XCUIElementTypeButton) {
      return;
    }
    if ([[FBXCElementSnapshotWrapper ensureWrapped:descendant].wdLabel isEqualToString:label]) {
      matchedButtonSnapshot = descendant;
    }
  }];
  XCUIElement *requestedButton = nil == matchedButtonSnapshot
    ? nil
    : [self elementForSnapshot:matchedButtonSnapshot inApplication:snapshotApplication];
  if (!requestedButton) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find button with label '%@' for alert: %@", label, alertSnapshot]
            buildError:error];
  }
  [requestedButton tap];
  return YES;
}

- (BOOL)clickElementMatchingClassChain:(NSString *)classChain error:(NSError **)error
{
  XCUIApplication *snapshotApplication = nil;
  id<FBXCElementSnapshot> alertSnapshot = [self alertSnapshotFromApplication:&snapshotApplication];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
  }
  XCUIElement *alertElement = [self elementForSnapshot:alertSnapshot inApplication:snapshotApplication];
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }

  XCUIElement *matchedElement = nil;
  @try {
    matchedElement = [[alertElement fb_descendantsMatchingClassChain:classChain
                                           shouldReturnAfterFirstMatch:YES] firstObject];
  } @catch (NSException *ex) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to match class chain selector '%@' for alert: %@. Original error: %@", classChain, alertSnapshot, ex.reason]
            buildError:error];
  }
  if (nil == matchedElement) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find any element matching class chain selector '%@' for alert: %@", classChain, alertSnapshot]
            buildError:error];
  }
  [matchedElement tap];
  return YES;
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
