/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBAlert.h"

#import <XCTest/XCUICoordinate.h>

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBFindElementCommands.h"
#import "FBSpringboardApplication.h"
#import "FBLogger.h"
#import "FBXCodeCompatibility.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCElementSnapshot.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"


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

- (BOOL)isSafariWebAlert
{
  return nil != self.alertElement
    && self.alertElement.elementType == XCUIElementTypeOther
    && [self.application.label isEqualToString:FB_SAFARI_APP_NAME];
}

- (NSString *)text
{
  XCUIElement *alert = self.alertElement;
  if (!alert) {
    return nil;
  }

  NSMutableArray<NSString *> *resultText = [NSMutableArray array];
  [alert.fb_lastSnapshot enumerateDescendantsUsingBlock:^(XCElementSnapshot *descendant) {
    if (descendant.elementType != XCUIElementTypeStaticText) {
      return;
    }
    NSString *label = descendant.wdLabel;
    if (nil != label) {
      [resultText addObject:[NSString stringWithFormat:@"%@", label]];
    } else {
      NSString *value = descendant.wdValue;
      if (nil != value) {
        [resultText addObject:[NSString stringWithFormat:@"%@", value]];
      }
    }
  }];
  if (resultText.count) {
    return [resultText componentsJoinedByString:@"\n"];
  }
  // return an empty string to reflect the fact there is an alert, but it does not contain any text
  return @"";
}

- (BOOL)typeText:(NSString *)text error:(NSError **)error
{
  XCUIElement *alert = self.alertElement;
  if (nil == alert) {
    return [[[FBErrorBuilder builder]
     withDescriptionFormat:@"No alert is open"]
    buildError:error];
  }
  
  NSPredicate *textCollectorPredicate = [NSPredicate predicateWithFormat:@"elementType IN {%lu,%lu}",
                                         XCUIElementTypeTextField, XCUIElementTypeSecureTextField];
  NSArray<XCUIElement *> *dstFields = [[alert descendantsMatchingType:XCUIElementTypeAny]
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
  return [dstFields.firstObject fb_typeText:text error:error];
}

- (NSArray *)buttonLabels
{
  XCUIElement *alert = self.alertElement;
  if (nil == alert) {
    return nil;
  }

  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  [alert.fb_lastSnapshot enumerateDescendantsUsingBlock:^(XCElementSnapshot *descendant) {
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
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [[[FBErrorBuilder builder]
     withDescriptionFormat:@"No alert is open"]
    buildError:error];
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
    acceptButton = (alertElement.elementType == XCUIElementTypeAlert || [self isSafariWebAlert])
      ? buttons.lastObject
      : buttons.firstObject;
  }
  return nil == acceptButton
    ? [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to find accept button for alert: %@", alertElement]
     buildError:error]
    : [acceptButton fb_tapWithError:error];
}

- (BOOL)dismissWithError:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [[[FBErrorBuilder builder]
     withDescriptionFormat:@"No alert is open"]
    buildError:error];
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
    dismissButton = (alertElement.elementType == XCUIElementTypeAlert || [self isSafariWebAlert])
      ? buttons.firstObject
      : buttons.lastObject;
  }
  return nil == dismissButton
    ? [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to find dismiss button for alert: %@", alertElement]
     buildError:error]
    : [dismissButton fb_tapWithError:error];
}

- (BOOL)clickAlertButton:(NSString *)label error:(NSError **)error
{
  XCUIElement *alertElement = self.alertElement;
  if (nil == alertElement) {
    return [[[FBErrorBuilder builder]
     withDescriptionFormat:@"No alert is open"]
    buildError:error];
  }

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == '%@'", label];
  XCUIElement *requestedButton = [[alertElement descendantsMatchingType:XCUIElementTypeButton]
                                  matchingPredicate:predicate].fb_firstMatch;
  if (!requestedButton) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Failed to find button with label %@ for alert: %@", label, alertElement]
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
