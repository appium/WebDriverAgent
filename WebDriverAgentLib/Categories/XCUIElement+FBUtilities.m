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
#import "FBElementUtils.h"
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
#import "XCUIApplication.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"
#import "XCUIElementQuery+FBHelpers.h"
#import "XCUIElement+FBUID.h"
#import "XCUIScreen.h"
#import "XCUIElement+FBResolve.h"

@implementation XCUIElement (FBUtilities)

- (id<FBXCElementSnapshot>)fb_takeSnapshot:(BOOL)isCustom
{
  __block id<FBXCElementSnapshot> snapshot = nil;
  @autoreleasepool {
    NSError *error = nil;
    snapshot = isCustom
      ? [self.fb_query fb_uniqueSnapshotWithError:&error]
      : (id<FBXCElementSnapshot>)[self snapshotWithError:&error];
    if (nil == snapshot) {
      [self fb_raiseStaleElementExceptionWithError:error];
    }
  }
  self.lastSnapshot = snapshot;
  return self.lastSnapshot;
}

- (id<FBXCElementSnapshot>)fb_standardSnapshot
{
  return [self fb_takeSnapshot:NO];
}

- (id<FBXCElementSnapshot>)fb_customSnapshot
{
  return [self fb_takeSnapshot:YES];
}

- (id<FBXCElementSnapshot>)fb_nativeSnapshot
{
  NSError *error = nil;
  BOOL isSuccessful = [self resolveOrRaiseTestFailure:NO error:&error];
  if (nil == self.lastSnapshot || !isSuccessful) {
    [self fb_raiseStaleElementExceptionWithError:error];
  }
  return self.lastSnapshot;
}

- (id<FBXCElementSnapshot>)fb_cachedSnapshot
{
  return [self.query fb_cachedSnapshot];
}

- (NSArray<XCUIElement *> *)fb_filterDescendantsWithSnapshots:(NSArray<id<FBXCElementSnapshot>> *)snapshots
                                                 onlyChildren:(BOOL)onlyChildren
{
  if (0 == snapshots.count) {
    return @[];
  }
  NSMutableArray<NSString *> *matchedIds = [NSMutableArray new];
  for (id<FBXCElementSnapshot> snapshot in snapshots) {
    @autoreleasepool {
      NSString *uid = [FBXCElementSnapshotWrapper wdUIDWithSnapshot:snapshot];
      if (nil != uid) {
        [matchedIds addObject:uid];
      }
    }
  }
  NSMutableArray<XCUIElement *> *matchedElements = [NSMutableArray array];
  NSString *uid = nil == self.lastSnapshot
    ? self.fb_uid
    : [FBXCElementSnapshotWrapper wdUIDWithSnapshot:self.lastSnapshot];
  if (nil != uid && [matchedIds containsObject:uid]) {
    XCUIElement *stableSelf = [self fb_stableInstanceWithUid:uid];
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

- (void)fb_raiseStaleElementExceptionWithError:(NSError *)error __attribute__((noreturn))
{
  NSString *hintText = @"Make sure the application UI has the expected state";
  if (nil != error && [error.localizedDescription containsString:@"Identity Binding"]) {
    hintText = [NSString stringWithFormat:@"%@. You could also try to switch the binding strategy using the 'boundElementsByIndex' setting for the element lookup", hintText];
  }
  NSString *reason = [NSString stringWithFormat:@"The previously found element \"%@\" is not present in the current view anymore. %@",
                      self.description, hintText];
  if (nil != error) {
    reason = [NSString stringWithFormat:@"%@. Original error: %@", reason, error.localizedDescription];
  }
  @throw [NSException exceptionWithName:FBStaleElementException reason:reason userInfo:@{}];
}

@end
