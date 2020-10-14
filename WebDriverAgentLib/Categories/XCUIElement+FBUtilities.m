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
#import "FBXCAXClientProxy.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIApplication.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCTElementSetTransformer-Protocol.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIElement+FBCaching.h"
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
    CGRect newFrame = self.frame;
    const BOOL isSameFrame = FBRectFuzzyEqualToRect(newFrame, frame, FBDefaultFrameFuzzyThreshold);
    frame = newFrame;
    return isSameFrame;
  }];
}

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
  if ([self isKindOfClass:XCUIApplication.class]) {
    return [[[(XCUIApplication *)self applicationImpl] currentProcess] lastSnapshot];
  }

  XCUIElementQuery *inputQuery = self.fb_query;
  NSMutableArray<id<XCTElementSetTransformer>> *transformersChain = [NSMutableArray array];
  XCElementSnapshot *rootElementSnapshot = nil;
  while (nil != inputQuery && nil != inputQuery.transformer) {
    [transformersChain insertObject:inputQuery.transformer atIndex:0];
    if (nil != inputQuery.rootElementSnapshot) {
      rootElementSnapshot = inputQuery.rootElementSnapshot;
    }
    inputQuery = inputQuery.inputQuery;
  }
  if (nil == rootElementSnapshot) {
    return nil;
  }

  NSMutableArray *snapshots = [NSMutableArray arrayWithObject:rootElementSnapshot];
  [snapshots addObjectsFromArray:rootElementSnapshot._allDescendants];
  NSOrderedSet *matchingSnapshots = [NSOrderedSet orderedSetWithArray:snapshots];
  @try {
    for (id<XCTElementSetTransformer> transformer in transformersChain) {
      matchingSnapshots = (NSOrderedSet *)[transformer transform:matchingSnapshots
                                                 relatedElements:nil];
    }
    return matchingSnapshots.count == 1 ? matchingSnapshots.firstObject : nil;
  } @catch (NSException *e) {
    [FBLogger logFmt:@"Got an unexpected error while retriveing the cached snapshot: %@", e.reason];
  }
  return nil;
}

- (nullable XCElementSnapshot *)fb_snapshotWithAllAttributes {
  NSMutableArray *allNames = [NSMutableArray arrayWithArray:FBStandardAttributeNames().allObjects];
  [allNames addObjectsFromArray:FBCustomAttributeNames().allObjects];
  return [self fb_snapshotWithAttributes:allNames.copy];
}

- (nullable XCElementSnapshot *)fb_snapshotWithAttributes:(NSArray<NSString *> *)attributeNames {
  if (![FBConfiguration canLoadSnapshotWithAttributes]) {
    return nil;
  }

  XCAccessibilityElement *axElement = self.fb_takeSnapshot.accessibilityElement;
  if (nil == axElement) {
    return nil;
  }
  NSTimeInterval axTimeout = [FBConfiguration snapshotTimeout];
  __block XCElementSnapshot *snapshotWithAttributes = nil;
  __block NSError *innerError = nil;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [FBXCTestDaemonsProxy tryToSetAxTimeout:axTimeout
                                 forProxy:proxy
                              withHandler:^(int res) {
    [self fb_requestSnapshot:axElement
           forAttributeNames:[NSSet setWithArray:attributeNames]
                       proxy:proxy
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
  } else {
    self.lastSnapshot = snapshotWithAttributes;
  }
  return snapshotWithAttributes;
}

- (void)fb_requestSnapshot:(XCAccessibilityElement *)accessibilityElement
         forAttributeNames:(NSSet<NSString *> *)attributeNames
                     proxy:(id<XCTestManager_ManagerInterface>)proxy
                     reply:(void (^)(XCElementSnapshot *, NSError *))block
{
  NSArray *axAttributes = FBCreateAXAttributes(attributeNames);
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
  return query.fb_allMatches;
}

- (BOOL)fb_waitUntilSnapshotIsStable
{
  return [self fb_waitUntilSnapshotIsStableWithTimeout:FB_ANIMATION_TIMEOUT];
}

- (BOOL)fb_waitUntilSnapshotIsStableWithTimeout:(NSTimeInterval)timeout
{
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [FBXCAXClientProxy.sharedClient notifyWhenNoAnimationsAreActiveForApplication:self.application reply:^{dispatch_semaphore_signal(sem);}];
  dispatch_time_t absoluteTimeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC));
  BOOL result = 0 == dispatch_semaphore_wait(sem, absoluteTimeout);
  if (!result) {
    [FBLogger logFmt:@"The applicaion has still not finished animations after %.2f seconds timeout", timeout];
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
    return FBToPngData([XCUIScreen.mainScreen screenshotDataForQuality:FBConfiguration.screenshotQuality
                                                      rect:elementRect
                                                     error:error]);
  }

#if !TARGET_OS_TV
  UIInterfaceOrientation orientation = self.application.interfaceOrientation;
  if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
    // Workaround XCTest bug when element frame is returned as in portrait mode even if the screenshot is rotated
    XCElementSnapshot *selfSnapshot = self.fb_isResolvedFromCache.boolValue
      ? self.lastSnapshot
      : self.fb_takeSnapshot;
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
