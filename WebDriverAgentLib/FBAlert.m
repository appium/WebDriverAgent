/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBAlert.h"

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBSpringboardApplication.h"
#import "FBLogger.h"
#import "FBXCodeCompatibility.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"


@interface FBAlert ()
@property (nonatomic, strong) XCUIApplication *application;
@property (nonatomic, strong, nullable) XCUIElement *element;
@end

@implementation FBAlert

+ (instancetype)alertWithApplication:(XCUIApplication *)application
{
  FBAlert *alert = [FBAlert new];
  alert.application = application;
  return alert;
}

+ (instancetype)alertWithElement:(XCUIElement *)element
{
  FBAlert *alert = [FBAlert new];
  alert.element = element;
  alert.application = element.application;
  return alert;
}

- (BOOL)isPresent
{
  return nil != self.alertElement && self.alertElement.exists;
}

- (BOOL)notPresentWithError:(NSError **)error
{
  return [[[FBErrorBuilder builder]
           withDescriptionFormat:@"No alert is open"]
          buildError:error];
}

- (BOOL)isSafariWebAlert
{
  return nil != self.alertElement
    && self.alertElement.elementType == XCUIElementTypeOther
    && [self.application.label isEqualToString:FB_SAFARI_APP_NAME];
}

- (NSString *)text
{
  if (!self.isPresent) {
    return nil;
  }

  NSMutableArray<NSString *> *resultText = [NSMutableArray array];
  XCElementSnapshot *snapshot = self.alertElement.fb_cachedSnapshot ?: self.alertElement.fb_lastSnapshot;
  [snapshot enumerateDescendantsUsingBlock:^(XCElementSnapshot *descendant) {
    XCUIElementType elementType = descendant.elementType;
    if (!(elementType == XCUIElementTypeTextView || elementType == XCUIElementTypeStaticText)) {
      return;
    }

    if (elementType == XCUIElementTypeTextView
        && [descendant fb_descendantsMatchingType:XCUIElementTypeStaticText].count > 0) {
      return;
    }
    if (elementType == XCUIElementTypeStaticText
        && nil != [descendant fb_parentMatchingType:XCUIElementTypeButton]) {
      return;
    }

    NSString *text = descendant.wdLabel ?: descendant.wdValue;
    if (nil != text) {
      [resultText addObject:[NSString stringWithFormat:@"%@", text]];
    }
  }];
  return [resultText componentsJoinedByString:@"\n"];
}

- (BOOL)typeText:(NSString *)text error:(NSError **)error
{
  if (!self.isPresent) {
    return [self notPresentWithError:error];
  }
  
  NSPredicate *textCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu}",
                                         XCUIElementTypeTextField, XCUIElementTypeSecureTextField];
  NSArray<XCUIElement *> *dstFields = [[self.alertElement descendantsMatchingType:XCUIElementTypeAny]
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
  // ignore possible clear errors
  [dstFields.firstObject fb_clearTextWithError:nil];
  return [dstFields.firstObject fb_typeText:text error:error];
}

- (NSArray *)buttonLabels
{
  if (!self.isPresent) {
    return nil;
  }

  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  XCElementSnapshot *snapshot = self.alertElement.fb_cachedSnapshot ?: self.alertElement.fb_lastSnapshot;
  [snapshot enumerateDescendantsUsingBlock:^(XCElementSnapshot *descendant) {
    if (descendant.elementType != XCUIElementTypeButton) {
      return;
    }
    NSString *label = descendant.wdLabel;
    if (nil != label) {
      [labels addObject:[NSString stringWithFormat:@"%@", label]];
    }
  }];
  return labels.copy;
}

- (BOOL)acceptWithError:(NSError **)error
{
  if (!self.isPresent) {
    return [self notPresentWithError:error];
  }

  XCUIElement *acceptButton = nil;
  if (FBConfiguration.acceptAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      acceptButton = [[self.alertElement fb_descendantsMatchingClassChain:FBConfiguration.acceptAlertButtonSelector
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
    NSArray<XCUIElement *> *buttons = [self.alertElement.fb_query
                                       descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
    acceptButton = (self.alertElement.elementType == XCUIElementTypeAlert || [self isSafariWebAlert])
      ? buttons.lastObject
      : buttons.firstObject;
  }
  return nil == acceptButton
    ? [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find accept button for alert: %@", self.alertElement]
     buildError:error]
    : [acceptButton fb_tapWithError:error];
}

- (BOOL)dismissWithError:(NSError **)error
{
  if (!self.isPresent) {
    return [self notPresentWithError:error];
  }

  XCUIElement *dismissButton = nil;
  if (FBConfiguration.dismissAlertButtonSelector.length) {
    NSString *errorReason = nil;
    @try {
      dismissButton = [[self.alertElement fb_descendantsMatchingClassChain:FBConfiguration.dismissAlertButtonSelector
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
    NSArray<XCUIElement *> *buttons = [self.alertElement.fb_query
                                       descendantsMatchingType:XCUIElementTypeButton].allElementsBoundByIndex;
    dismissButton = (self.alertElement.elementType == XCUIElementTypeAlert || [self isSafariWebAlert])
      ? buttons.firstObject
      : buttons.lastObject;
  }
  return nil == dismissButton
    ? [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Failed to find dismiss button for alert: %@", self.alertElement]
     buildError:error]
    : [dismissButton fb_tapWithError:error];
}

- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error
{
  if (!self.isPresent) {
    return [self notPresentWithError:error];
  }

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
  XCUIElement *requestedButton = [[self.alertElement descendantsMatchingType:XCUIElementTypeButton]
                                  matchingPredicate:predicate].fb_firstMatch;
  if (!requestedButton) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find button with label '%@' for alert: %@", label, self.alertElement]
            buildError:error];
  }
  return [requestedButton fb_tapWithError:error];
}

- (XCUIElement *)alertElement
{
  if (nil == self.element) {
    self.element = self.application.fb_alertElement ?: [FBSpringboardApplication fb_springboard].fb_alertElement;
  }
  return self.element;
}

@end
