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
#import "FBXCElementSnapshot.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCTElementSetTransformer-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIApplicationProcess+FBQuiescence.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"
#import "XCUIElementQuery+FBHelpers.h"
#import "XCUIElement+FBUID.h"
#import "XCUIScreen.h"
#import "XCUIElement+FBResolve.h"

#define DEFAULT_AX_TIMEOUT 60.

@implementation XCUIElement (FBUtilities)

- (id<FBXCElementSnapshot>)fb_takeSnapshot
{
  NSError *error = nil;
  self.fb_isResolvedFromCache = @(NO);
  self.lastSnapshot = [self.fb_query fb_uniqueSnapshotWithError:&error];
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

- (id<FBXCElementSnapshot>)fb_cachedSnapshot
{
  return [self.query fb_cachedSnapshot];
}

- (nullable id<FBXCElementSnapshot>)fb_snapshotWithAllAttributesAndMaxDepth:(NSNumber *)maxDepth
{
  NSMutableArray *allNames = [NSMutableArray arrayWithArray:FBStandardAttributeNames()];
  [allNames addObjectsFromArray:FBCustomAttributeNames()];
  return [self fb_snapshotWithAttributes:allNames.copy
                                maxDepth:maxDepth];
}

- (nullable id<FBXCElementSnapshot>)fb_snapshotWithAttributes:(NSArray<NSString *> *)attributeNames
                                                     maxDepth:(NSNumber *)maxDepth
{
  NSSet<NSString *> *standardAttributes = [NSSet setWithArray:FBStandardAttributeNames()];
  id<FBXCElementSnapshot> snapshot = self.fb_takeSnapshot;
  NSTimeInterval axTimeout = FBConfiguration.customSnapshotTimeout;
  if (nil == attributeNames
      || [[NSSet setWithArray:attributeNames] isSubsetOfSet:standardAttributes]
      || axTimeout < DBL_EPSILON) {
    // return the "normal" element snapshot if no custom attributes are requested
    return snapshot;
  }

  id<FBXCAccessibilityElement> axElement = snapshot.accessibilityElement;
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
  id<FBXCElementSnapshot> snapshotWithAttributes = [FBXCAXClientProxy.sharedClient snapshotForElement:axElement
                                                                                           attributes:attributeNames
                                                                                             maxDepth:maxDepth
                                                                                                error:&error];
  if (nil == snapshotWithAttributes) {
    NSString *description = [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_description;
    [FBLogger logFmt:@"Cannot take a snapshot with attribute(s) %@ of '%@' after %.2f seconds",
     attributeNames, description, axTimeout];
    [FBLogger logFmt:@"This timeout could be customized via '%@' setting", FB_SETTING_CUSTOM_SNAPSHOT_TIMEOUT];
    [FBLogger logFmt:@"Internal error: %@", error.localizedDescription];
    [FBLogger logFmt:@"Falling back to the default snapshotting mechanism for the element '%@' (some attribute values, like visibility or accessibility might not be precise though)", description];
    snapshotWithAttributes = self.lastSnapshot;
  } else {
    self.lastSnapshot = snapshotWithAttributes;
  }

  if (isTimeoutSet) {
    [FBXCAXClientProxy.sharedClient setAXTimeout:DEFAULT_AX_TIMEOUT error:nil];
  }
  return snapshotWithAttributes;
}

- (NSArray<XCUIElement *> *)fb_filterDescendantsWithSnapshots:(NSArray<id<FBXCElementSnapshot>> *)snapshots
                                                      selfUID:(NSString *)selfUID
                                                 onlyChildren:(BOOL)onlyChildren
{
  if (0 == snapshots.count) {
    return @[];
  }
  NSMutableArray<NSString *> *matchedIds = [NSMutableArray new];
  for (id<FBXCElementSnapshot> snapshot in snapshots) {
    NSString *uid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:snapshot];
    if (nil != uid) {
      [matchedIds addObject:uid];
    }
  }
  NSMutableArray<XCUIElement *> *matchedElements = [NSMutableArray array];
  NSString *uid = selfUID;
  if (nil == uid) {
    uid = self.fb_isResolvedFromCache.boolValue
      ? [FBXCElementSnapshotWrapper wdUIDWithSnapshot:self.lastSnapshot]
      : self.fb_uid;
  }
  if (nil != uid && [matchedIds containsObject:uid]) {
    XCUIElement *stableSelf = self.fb_stableInstance;
    stableSelf.fb_isResolvedNatively = @NO;
    if (1 == snapshots.count) {
      return @[stableSelf];
    }
    [matchedElements addObject:stableSelf];
  }
  XCUIElementType type = XCUIElementTypeAny;
  NSArray<NSNumber *> *uniqueTypes = [snapshots valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", FBStringify(XCUIElement, elementType)]];
  if (uniqueTypes && [uniqueTypes count] == 1) {
    type = [uniqueTypes.firstObject intValue];
  }
  XCUIElementQuery *query = onlyChildren
    ? [self.fb_query childrenMatchingType:type]
    : [self.fb_query descendantsMatchingType:type];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@",FBStringify(FBXCElementSnapshotWrapper, fb_uid), matchedIds];
  [matchedElements addObjectsFromArray:[query matchingPredicate:predicate].allElementsBoundByIndex];

  for (XCUIElement *el in matchedElements) {
    el.fb_isResolvedNatively = @NO;
  }
  return matchedElements.copy;
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
   fb_waitForQuiescenceIncludingAnimationsIdle:YES];
  if (previousQuiescence != self.application.fb_shouldWaitForQuiescence) {
    self.application.fb_shouldWaitForQuiescence = previousQuiescence;
  }
  FBConfiguration.waitForIdleTimeout = previousTimeout;
}

@end
