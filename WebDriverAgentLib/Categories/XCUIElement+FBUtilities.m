/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBUtilities.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBImageUtils.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRunLoopSpinner.h"
#import "FBSettings.h"
#import "FBScreenshot.h"
#import "FBXCAXClientProxy.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCTElementSetTransformer-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"
#import "XCUIElementQuery+FBHelpers.h"
#import "XCUIElement+FBUID.h"
#import "XCUIScreen.h"
#import "XCUIElement+FBResolve.h"

#define DEFAULT_AX_TIMEOUT 60.

@implementation XCUIElement (FBUtilities)

- (XCElementSnapshot *)fb_takeSnapshot
{
  NSError *error = nil;
  self.fb_isResolvedFromCache = @(NO);
  if (self.query.fb_isUniqueSnapshotSupported) {
    self.lastSnapshot = [self.fb_query fb_uniqueSnapshotWithError:&error];
  } else {
    self.lastSnapshot = nil;
    // TODO: Remove this branch after Xcode10 support is dropped
    [self fb_resolveWithError:&error];
  }
  if (nil == self.lastSnapshot) {
    NSString *hintText = @"Make sure the application UI has the expected state";
    if (nil != error
        && [error.localizedDescription containsString:@"Identity Binding"]) {
      hintText = [NSString stringWithFormat:@"%@. You could also try to switch the binding strategy using the 'boundElementsByIndex' setting for the element lookup", hintText];
    }
    NSString *reason = [NSString stringWithFormat:@"The previously found element \"%@\" is not present in the current view anymore. %@", self.description, hintText];
    if (nil != error) {
      reason = [NSString stringWithFormat:@"%@. Original error: %@", reason, error.localizedDescription];
    }
    @throw [NSException exceptionWithName:FBStaleElementException reason:reason userInfo:@{}];
  }
  return self.lastSnapshot;
}

- (XCElementSnapshot *)fb_cachedSnapshot
{
  return [self.query fb_cachedSnapshot];
}

- (nullable XCElementSnapshot *)fb_snapshotWithAllAttributesAndMaxDepth:(NSNumber *)maxDepth
{
  NSMutableArray *allNames = [NSMutableArray arrayWithArray:FBStandardAttributeNames()];
  [allNames addObjectsFromArray:FBCustomAttributeNames()];
  return [self fb_snapshotWithAttributes:allNames.copy
                                maxDepth:maxDepth];
}

- (nullable XCElementSnapshot *)fb_snapshotWithAttributes:(NSArray<NSString *> *)attributeNames
                                                 maxDepth:(NSNumber *)maxDepth
{
  NSSet<NSString *> *standardAttributes = [NSSet setWithArray:FBStandardAttributeNames()];
  XCElementSnapshot *snapshot = self.fb_takeSnapshot;
  NSTimeInterval axTimeout = FBConfiguration.customSnapshotTimeout;
  if (nil == attributeNames
      || [[NSSet setWithArray:attributeNames] isSubsetOfSet:standardAttributes]
      || axTimeout < DBL_EPSILON) {
    // return the "normal" element snapshot if no custom attributes are requested
    return snapshot;
  }

  XCAccessibilityElement *axElement = snapshot.accessibilityElement;
  if (nil == axElement) {
    return nil;
  }

  NSError *setTimeoutError;
  BOOL isTimeoutSet = [FBXCAXClientProxy.sharedClient setAXTimeout:axTimeout
                                                             error:&setTimeoutError];
  if (!isTimeoutSet) {
    [FBLogger logFmt:@"Cannot set snapshoting timeout to %.1fs. Original error: %@",
     axTimeout, setTimeoutError.localizedDescription];
  }

  NSError *error;
  XCElementSnapshot *snapshotWithAttributes = [FBXCAXClientProxy.sharedClient snapshotForElement:axElement
                                                                                      attributes:attributeNames
                                                                                        maxDepth:maxDepth
                                                                                           error:&error];
  if (nil == snapshotWithAttributes) {
    [FBLogger logFmt:@"Cannot take a snapshot with attribute(s) %@ of '%@' after %.2f seconds",
     attributeNames, snapshot.fb_description, axTimeout];
    [FBLogger logFmt:@"This timeout could be customized via '%@' setting", FB_SETTING_CUSTOM_SNAPSHOT_TIMEOUT];
    [FBLogger logFmt:@"Internal error: %@", error.localizedDescription];
    [FBLogger logFmt:@"Falling back to the default snapshotting mechanism for the element '%@' (some attribute values, like visibility or accessibility might not be precise though)", snapshot.fb_description];
    snapshotWithAttributes = self.lastSnapshot;
  } else {
    self.lastSnapshot = snapshotWithAttributes;
  }

  if (isTimeoutSet) {
    [FBXCAXClientProxy.sharedClient setAXTimeout:DEFAULT_AX_TIMEOUT error:nil];
  }
  return snapshotWithAttributes;
}

- (NSArray<XCUIElement *> *)fb_filterDescendantsWithSnapshots:(NSArray<XCElementSnapshot *> *)snapshots
                                                      selfUID:(NSString *)selfUID
                                                 onlyChildren:(BOOL)onlyChildren
{
  if (0 == snapshots.count) {
    return @[];
  }
  NSArray<NSString *> *sortedIds = [snapshots valueForKey:FBStringify(XCUIElement, wdUID)];
  NSMutableArray<XCUIElement *> *matchedElements = [NSMutableArray array];
  NSString *uid = selfUID;
  if (nil == uid) {
    uid = self.fb_isResolvedFromCache.boolValue
      ? self.lastSnapshot.fb_uid
      : self.fb_uid;
  }
  if ([sortedIds containsObject:uid]) {
    if (1 == snapshots.count) {
      return @[self];
    }
    [matchedElements addObject:self];
  }
  XCUIElementType type = XCUIElementTypeAny;
  NSArray<NSNumber *> *uniqueTypes = [snapshots valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", FBStringify(XCUIElement, elementType)]];
  if (uniqueTypes && [uniqueTypes count] == 1) {
    type = [uniqueTypes.firstObject intValue];
  }
  XCUIElementQuery *query = onlyChildren
    ? [self.fb_query childrenMatchingType:type]
    : [self.fb_query descendantsMatchingType:type];
  query = [query matchingPredicate:[NSPredicate predicateWithFormat:@"%K IN %@", FBStringify(XCUIElement, wdUID), sortedIds]];
  if (1 == snapshots.count) {
    XCUIElement *result = query.fb_firstMatch;
    result.fb_isResolvedNatively = @NO;
    return result ? @[result] : @[];
  }
  // Rely here on the fact, that XPath always returns query results in the same
  // order they appear in the document, which means we don't need to resort the resulting
  // array. Although, if it turns out this is still not the case then we could always
  // uncomment the sorting procedure below:
  //  query = [query sorted:(id)^NSComparisonResult(XCElementSnapshot *a, XCElementSnapshot *b) {
  //    NSUInteger first = [sortedIds indexOfObject:a.wdUID];
  //    NSUInteger second = [sortedIds indexOfObject:b.wdUID];
  //    if (first < second) {
  //      return NSOrderedAscending;
  //    }
  //    if (first > second) {
  //      return NSOrderedDescending;
  //    }
  //    return NSOrderedSame;
  //  }];
  NSArray<XCUIElement *> *result = query.fb_allMatches;
  for (XCUIElement *el in result) {
    el.fb_isResolvedNatively = @NO;
  }
  return result;
}

- (void)fb_waitUntilStable
{
  [self fb_waitUntilStableWithTimeout:FBConfiguration.waitForIdleTimeout];
}

- (void)fb_waitUntilStableWithTimeout:(NSTimeInterval)timeout
{
  if (timeout < DBL_EPSILON) {
    return;
  }

  NSTimeInterval previousTimeout = FBConfiguration.waitForIdleTimeout;
  BOOL previousQuiescence = self.application.fb_shouldWaitForQuiescence;
  FBConfiguration.waitForIdleTimeout = timeout;
  if (!previousQuiescence) {
    self.application.fb_shouldWaitForQuiescence = YES;
  }
  [[[self.application applicationImpl] currentProcess]
   waitForQuiescenceIncludingAnimationsIdle:YES];
  if (previousQuiescence != self.application.fb_shouldWaitForQuiescence) {
    self.application.fb_shouldWaitForQuiescence = previousQuiescence;
  }
  FBConfiguration.waitForIdleTimeout = previousTimeout;
}

- (NSData *)fb_screenshotWithError:(NSError **)error
{
  XCElementSnapshot *selfSnapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  if (CGRectIsEmpty(selfSnapshot.frame)) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Cannot get a screenshot of zero-sized element"] build];
    }
    return nil;
  }

  CGRect elementRect = selfSnapshot.frame;
#if !TARGET_OS_TV
  UIInterfaceOrientation orientation = self.application.interfaceOrientation;
  if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
    // Workaround XCTest bug when element frame is returned as in portrait mode even if the screenshot is rotated
    NSArray<XCElementSnapshot *> *ancestors = selfSnapshot.fb_ancestors;
    XCElementSnapshot *parentWindow = nil;
    if (1 == ancestors.count) {
      parentWindow = selfSnapshot;
    } else if (ancestors.count > 1) {
      parentWindow = [ancestors objectAtIndex:ancestors.count - 2];
    }
    if (nil != parentWindow) {
      CGRect appFrame = ancestors.lastObject.frame;
      CGRect parentWindowFrame = parentWindow.frame;
      if (CGRectEqualToRect(appFrame, parentWindowFrame)
          || (appFrame.size.width > appFrame.size.height && parentWindowFrame.size.width > parentWindowFrame.size.height)
          || (appFrame.size.width < appFrame.size.height && parentWindowFrame.size.width < parentWindowFrame.size.height)) {
          CGPoint fixedOrigin = orientation == UIInterfaceOrientationLandscapeLeft ?
          CGPointMake(appFrame.size.height - elementRect.origin.y - elementRect.size.height, elementRect.origin.x) :
        CGPointMake(elementRect.origin.y, appFrame.size.width - elementRect.origin.x - elementRect.size.width);
        elementRect = CGRectMake(fixedOrigin.x, fixedOrigin.y, elementRect.size.height, elementRect.size.width);
      }
    }
  }
#endif

  // adjust element rect for the actual screen scale
  XCUIScreen *mainScreen = XCUIScreen.mainScreen;
  elementRect = CGRectMake(elementRect.origin.x * mainScreen.scale, elementRect.origin.y * mainScreen.scale,
                           elementRect.size.width * mainScreen.scale, elementRect.size.height * mainScreen.scale);

  return [FBScreenshot takeInOriginalResolutionWithQuality:FBConfiguration.screenshotQuality
                                                      rect:elementRect
                                                     error:error];
}

@end
