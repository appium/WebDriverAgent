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

#import "FBAlert.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBImageUtils.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRunLoopSpinner.h"
#import "FBXCAXClientProxy.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTElementSetTransformer-Protocol.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"
#import "XCUIScreen.h"
#import "XCUIElement+FBUID.h"

@implementation XCUIElement (FBUtilities)

static const NSTimeInterval FB_ANIMATION_TIMEOUT = 5.0;

- (BOOL)fb_waitUntilFrameIsStable
{
  __block CGRect frame = self.frame;
  // Initial wait
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  return
  [[[FBRunLoopSpinner new]
    timeout:10.]
   spinUntilTrue:^BOOL{
    const BOOL isSameFrame = FBRectFuzzyEqualToRect(self.frame, frame, FBDefaultFrameFuzzyThreshold);
    frame = self.frame;
    return isSameFrame;
  }];
}

- (BOOL)fb_isObstructedByAlert
{
  return [[FBAlert alertWithApplication:self.application].alertElement fb_obstructsElement:self];
}

- (BOOL)fb_obstructsElement:(XCUIElement *)element
{
  if (!self.exists) {
    return NO;
  }
  XCElementSnapshot *snapshot = self.fb_lastSnapshot;
  XCElementSnapshot *elementSnapshot = element.fb_lastSnapshot;
  if ([snapshot _isAncestorOfElement:elementSnapshot]) {
    return NO;
  }
  if ([snapshot _matchesElement:elementSnapshot]) {
    return NO;
  }
  return YES;
}

- (XCElementSnapshot *)fb_lastSnapshot
{
  return [self.query fb_elementSnapshotForDebugDescription];
}

- (nullable XCElementSnapshot *)fb_snapshotWithAllAttributes {
  NSMutableArray *allNames = [NSMutableArray arrayWithArray:FBStandardAttributeNames().allObjects];
  [allNames addObjectsFromArray:FBCustomAttributeNames().allObjects];
  return [self fb_snapshotWithAttributes:allNames.copy];
}

- (nullable XCElementSnapshot *)fb_snapshotWithAttributes:(NSArray<NSString *> *)attributeNames {
  if (![FBConfiguration shouldLoadSnapshotWithAttributes]) {
    return nil;
  }
  
  [self fb_nativeResolve];
  
  NSTimeInterval axTimeout = [FBConfiguration snapshotTimeout];
  __block XCElementSnapshot *snapshotWithAttributes = nil;
  __block NSError *innerError = nil;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  XCAccessibilityElement *axElement = FBConfiguration.includeNonModalElements && self.class.fb_supportsNonModalElementsInclusion
    ? self.query.includingNonModalElements.rootElementSnapshot.accessibilityElement
    : self.lastSnapshot.accessibilityElement;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [FBXCTestDaemonsProxy tryToSetAxTimeout:axTimeout
                                 forProxy:proxy
                              withHandler:^(int res) {
    [self fb_requestSnapshot:axElement
           forAttributeNames:[NSSet setWithArray:attributeNames]
                       reply:^(XCElementSnapshot *snapshot, NSError *error) {
      if (nil == error) {
        snapshotWithAttributes = snapshot;
      } else {
        innerError = error;
      }
      dispatch_semaphore_signal(sem);
    }];
  }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(axTimeout * NSEC_PER_SEC)));
  if (nil == snapshotWithAttributes) {
    [FBLogger logFmt:@"Cannot take the snapshot of %@ after %@ seconds", self.description, @(axTimeout)];
    if (nil != innerError) {
      [FBLogger logFmt:@"Internal error: %@", innerError.description];
    }
  }
  return snapshotWithAttributes;
}

- (void)fb_requestSnapshot:(XCAccessibilityElement *)accessibilityElement
         forAttributeNames:(NSSet<NSString *> *)attributeNames
                     reply:(void (^)(XCElementSnapshot *, NSError *))block
{
  NSArray *axAttributes = FBCreateAXAttributes(attributeNames);
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  if (XCUIElement.fb_isSdk11SnapshotApiSupported) {
    // XCode 11 has a new snapshot api and the old one will be deprecated soon
    [proxy _XCT_requestSnapshotForElement:accessibilityElement
                               attributes:axAttributes
                               parameters:FBXCAXClientProxy.sharedClient.defaultParameters
                                    reply:block];
  } else {
    [proxy _XCT_snapshotForElement:accessibilityElement
                        attributes:axAttributes
                        parameters:FBXCAXClientProxy.sharedClient.defaultParameters
                             reply:block];
  }
}

- (XCElementSnapshot *)fb_lastSnapshotFromQuery
{
  XCElementSnapshot *snapshot = nil;
  @try {
    XCUIElementQuery *rootQuery = self.fb_query;
    while (rootQuery != nil && rootQuery.rootElementSnapshot == nil) {
      rootQuery = rootQuery.inputQuery;
    }
    if (rootQuery != nil) {
      NSMutableArray *snapshots = [NSMutableArray arrayWithObject:rootQuery.rootElementSnapshot];
      [snapshots addObjectsFromArray:rootQuery.rootElementSnapshot._allDescendants];
      NSOrderedSet *matchingSnapshots = (NSOrderedSet *)[self.query.transformer transform:[NSOrderedSet orderedSetWithArray:snapshots] relatedElements:nil];
      if (matchingSnapshots != nil && matchingSnapshots.count == 1) {
        snapshot = matchingSnapshots[0];
      }
    }
  } @catch (NSException *) {
    snapshot = nil;
  }
  return snapshot ?: self.fb_lastSnapshot;
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
  if ([sortedIds containsObject:(selfUID ?: self.fb_uid)]) {
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
    return result ? @[result] : @[];
  }
  // Rely here on the fact, that XPath always returns query resulsts in the same
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
  return query.allElementsBoundByAccessibilityElement;
}

- (BOOL)fb_waitUntilSnapshotIsStable
{
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [FBXCAXClientProxy.sharedClient notifyWhenNoAnimationsAreActiveForApplication:self.application reply:^{dispatch_semaphore_signal(sem);}];
  dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FB_ANIMATION_TIMEOUT * NSEC_PER_SEC));
  BOOL result = 0 == dispatch_semaphore_wait(sem, timeout);
  if (!result) {
    [FBLogger logFmt:@"The applicaion has still not finished animations after %.2f seconds timeout", FB_ANIMATION_TIMEOUT];
  }
  return result;
}

- (NSData *)fb_screenshotWithError:(NSError **)error
{
  if (CGRectIsEmpty(self.frame)) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Cannot get a screenshot of zero-sized element"] build];
    }
    return nil;
  }

  CGRect elementRect = self.frame;

  if (@available(iOS 13.0, *)) {
    // landscape also works correctly on over iOS13 x Xcode 11
    return [XCUIScreen.mainScreen screenshotDataForQuality:FBConfiguration.screenshotQuality
                                                      rect:elementRect
                                                     error:error];
  }

#if !TARGET_OS_TV
  UIInterfaceOrientation orientation = self.application.interfaceOrientation;
  if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
    // Workaround XCTest bug when element frame is returned as in portrait mode even if the screenshot is rotated
    XCElementSnapshot *selfSnapshot = self.fb_lastSnapshot;
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
  NSData *imageData = [XCUIScreen.mainScreen screenshotDataForQuality:FBConfiguration.screenshotQuality
                                                                 rect:elementRect
                                                                error:error];
#if !TARGET_OS_TV
  if (nil == imageData) {
    return nil;
  }
  return FBAdjustScreenshotOrientationForApplication(imageData, orientation);
#else
  return imageData;
#endif
}

@end
