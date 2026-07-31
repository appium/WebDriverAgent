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

/**
 XCUIElement that represents the alert, resolved via the interactive
 XCUIElementQuery-based lookup. isPresent/text/buttonLabels/
 acceptWithError:/dismissWithError:/clickAlertButton:error:/
 clickElementMatchingClassChain:error:/typeText:error: all resolve through
 this method as their own presence check. Not cached: every call re-resolves
 against the live UI.
 */
- (nullable XCUIElement *)alertElement;

/**
 Retrieve an alert element hosted by the iOS 18+ limited access permission
 prompt process. See https://github.com/appium/appium/issues/20591

 @return Alert element instance if the prompt is present, otherwise nil
 */
+ (nullable XCUIElement *)fb_limitedAccessPromptAlertElement;

/**
 Snapshots an already-resolved alert element, tolerating the element having
 gone stale in the (small) window between it being resolved and this call -
 fb_customSnapshot throws FBStaleElementException rather than returning nil
 in that case, so callers must not assume a nil-coalescing fallback to it is
 enough to guard against a missing snapshot.

 @return The element's snapshot, or nil if it could not be taken
 */
- (nullable id<FBXCElementSnapshot>)snapshotForAlertElement:(XCUIElement *)element;

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
  return nil != self.alertElement;
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
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return nil;
  }
  id<FBXCElementSnapshot> snapshot = [self snapshotForAlertElement:alertElement];
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
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }

  NSPredicate *textCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu}",
                                         XCUIElementTypeTextField, XCUIElementTypeSecureTextField];
  NSArray<XCUIElement *> *dstFields = [[alertElement descendantsMatchingType:XCUIElementTypeAny]
                                       matchingPredicate:textCollectorPredicate].allElementsBoundByIndex;
  if (dstFields.count > 1) {
    return [[[FBErrorBuilder builder]
      withDescriptionFormat:@"The alert contains more than one input field"]
     buildError:error];
  }
  if (0 == dstFields.count) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The alert contains no input fields"]
            buildError:error];
  }
  return [dstFields.firstObject fb_typeText:text
                                shouldClear:YES
                                      error:error];
}

- (NSArray *)buttonLabels
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return nil;
  }
  id<FBXCElementSnapshot> alertSnapshot = [self snapshotForAlertElement:alertElement];
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

- (BOOL)acceptWithError:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }
  id<FBXCElementSnapshot> alertSnapshot = [self snapshotForAlertElement:alertElement];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
  }

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
    return [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find accept button for alert: %@", alertElement]
       buildError:error];
  }
  [acceptButton tap];
  return YES;
}

- (BOOL)dismissWithError:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }
  id<FBXCElementSnapshot> alertSnapshot = [self snapshotForAlertElement:alertElement];
  if (nil == alertSnapshot) {
    return [self notPresentWithError:error];
  }

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
    return [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find dismiss button for alert: %@", alertElement]
            buildError:error];
  }
  [dismissButton tap];
  return YES;
}

- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
  XCUIElement *requestedButton = [[alertElement descendantsMatchingType:XCUIElementTypeButton]
                                  matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
  if (!requestedButton) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find button with label '%@' for alert: %@", label, alertElement]
            buildError:error];
  }
  [requestedButton tap];
  return YES;
}

- (BOOL)clickElementMatchingClassChain:(NSString *)classChain error:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [self notPresentWithError:error];
  }

  XCUIElement *matchedElement = nil;
  @try {
    matchedElement = [[alertElement fb_descendantsMatchingClassChain:classChain
                                           shouldReturnAfterFirstMatch:YES] firstObject];
  } @catch (NSException *ex) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to match class chain selector '%@' for alert: %@. Original error: %@", classChain, alertElement, ex.reason]
            buildError:error];
  }
  if (nil == matchedElement) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find any element matching class chain selector '%@' for alert: %@", classChain, alertElement]
            buildError:error];
  }
  [matchedElement tap];
  return YES;
}

- (nullable XCUIElement *)alertElement
{
  @try {
    XCUIApplication *systemApp = XCUIApplication.fb_systemApplication;
    XCUIElement *element;
    if ([systemApp fb_isSameAppAs:self.application]) {
      element = systemApp.fb_alertElement;
    } else {
      element = systemApp.fb_alertElement ?: self.application.fb_alertElement;
    }
    if (nil == element) {
      element = [self.class fb_limitedAccessPromptAlertElement];
    }
    return element;
  } @catch (NSException *) {
    return nil;
  }
}

+ (nullable XCUIElement *)fb_limitedAccessPromptAlertElement
{
  XCUIApplication *promptApp = XCUIApplication.fb_limitedAccessPromptApplication;
  return nil == promptApp ? nil : promptApp.fb_alertElement;
}

- (nullable id<FBXCElementSnapshot>)snapshotForAlertElement:(XCUIElement *)element
{
  @try {
    return element.lastSnapshot ?: [element fb_customSnapshot];
  } @catch (NSException *) {
    return nil;
  }
}

@end
