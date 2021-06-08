/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCodeCompatibility.h"

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElementQuery.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"

static const NSTimeInterval APP_STATE_CHANGE_TIMEOUT = 5.0;

static BOOL FBShouldUseOldElementRootSelector = NO;
static dispatch_once_t onceRootElementToken;
@implementation XCElementSnapshot (FBCompatibility)

- (XCElementSnapshot *)fb_rootElement
{
  dispatch_once(&onceRootElementToken, ^{
    FBShouldUseOldElementRootSelector = [self respondsToSelector:@selector(_rootElement)];
  });
  if (FBShouldUseOldElementRootSelector) {
    return [self _rootElement];
  }
  return [self rootElement];
}

+ (id)fb_axAttributesForElementSnapshotKeyPathsIOS:(id)arg1
{
  return [self.class axAttributesForElementSnapshotKeyPaths:arg1 isMacOS:NO];
}

+ (nullable SEL)fb_attributesForElementSnapshotKeyPathsSelector
{
  static SEL attributesForElementSnapshotKeyPathsSelector = nil;
  static dispatch_once_t attributesForElementSnapshotKeyPathsSelectorToken;
  dispatch_once(&attributesForElementSnapshotKeyPathsSelectorToken, ^{
    if ([self.class respondsToSelector:@selector(snapshotAttributesForElementSnapshotKeyPaths:)]) {
      attributesForElementSnapshotKeyPathsSelector = @selector(snapshotAttributesForElementSnapshotKeyPaths:);
    } else if ([self.class respondsToSelector:@selector(axAttributesForElementSnapshotKeyPaths:)]) {
      attributesForElementSnapshotKeyPathsSelector = @selector(axAttributesForElementSnapshotKeyPaths:);
    } else if ([self.class respondsToSelector:@selector(axAttributesForElementSnapshotKeyPaths:isMacOS:)]) {
      attributesForElementSnapshotKeyPathsSelector = @selector(fb_axAttributesForElementSnapshotKeyPathsIOS:);
    }
  });
  return attributesForElementSnapshotKeyPathsSelector;
}

@end


NSString *const FBApplicationMethodNotSupportedException = @"FBApplicationMethodNotSupportedException";

static BOOL FBShouldUseOldAppWithPIDSelector = NO;
static dispatch_once_t onceAppWithPIDToken;
@implementation XCUIApplication (FBCompatibility)

+ (instancetype)fb_applicationWithPID:(pid_t)processID
{
  dispatch_once(&onceAppWithPIDToken, ^{
    FBShouldUseOldAppWithPIDSelector = [XCUIApplication respondsToSelector:@selector(appWithPID:)];
  });
  if (0 == processID) {
    return nil;
  }

  if (FBShouldUseOldAppWithPIDSelector) {
    return [self appWithPID:processID];
  }
  return [self applicationWithPID:processID];
}

- (void)fb_activate
{
  [self activate];
  if (![self waitForState:XCUIApplicationStateRunningForeground timeout:APP_STATE_CHANGE_TIMEOUT / 2] || ![self fb_waitForAppElement:APP_STATE_CHANGE_TIMEOUT / 2]) {
    [FBLogger logFmt:@"The application '%@' is not running in foreground after %.2f seconds", self.bundleID, APP_STATE_CHANGE_TIMEOUT];
  }
}

- (void)fb_terminate
{
  [self terminate];
  if (![self waitForState:XCUIApplicationStateNotRunning timeout:APP_STATE_CHANGE_TIMEOUT]) {
    [FBLogger logFmt:@"The active application is still '%@' after %.2f seconds timeout", self.bundleID, APP_STATE_CHANGE_TIMEOUT];
  }
}

- (NSUInteger)fb_state
{
  return [[self valueForKey:@"state"] intValue];
}

@end


@implementation XCUIElementQuery (FBCompatibility)

- (BOOL)fb_isUniqueSnapshotSupported
{
  static dispatch_once_t onceToken;
  static BOOL isUniqueMatchingSnapshotAvailable;
  dispatch_once(&onceToken, ^{
    isUniqueMatchingSnapshotAvailable = [self respondsToSelector:@selector(uniqueMatchingSnapshotWithError:)];
  });
  return isUniqueMatchingSnapshotAvailable;
}

- (XCElementSnapshot *)fb_uniqueSnapshotWithError:(NSError **)error
{
  return [self uniqueMatchingSnapshotWithError:error];
}

- (XCUIElement *)fb_firstMatch
{
  XCUIElement* match = FBConfiguration.useFirstMatch
    ? self.firstMatch
    : self.fb_allMatches.firstObject;
  return [match exists] ? match : nil;
}

- (NSArray<XCUIElement *> *)fb_allMatches
{
  return FBConfiguration.boundElementsByIndex
    ? self.allElementsBoundByIndex
    : self.allElementsBoundByAccessibilityElement;
}

@end


@implementation XCUIElement (FBCompatibility)

- (BOOL)fb_resolveWithError:(NSError **)error
{
  @try {
    // The order here matters
    if ([self respondsToSelector:@selector(resolveOrRaiseTestFailure)]) {
      [self resolveOrRaiseTestFailure];
      return YES;
    } else if ([self respondsToSelector:@selector(resolve:)]) {
      return [self resolve:error];
    } else if ([self respondsToSelector:@selector(resolve)]) {
      [self resolve];
      return nil != self.lastSnapshot;
    }
  } @catch (NSException *e) {
    if (nil != e.reason) {
      return [[FBErrorBuilder.builder withDescription:(NSString *)e.reason] buildError:error];
    }
  }
  return [[FBErrorBuilder.builder withDescription:@"Cannot find a matching method to resolve elements. Please contact Appium developers"] buildError:error];
}

+ (BOOL)fb_supportsNonModalElementsInclusion
{
  static dispatch_once_t hasIncludingNonModalElements;
  static BOOL result;
  dispatch_once(&hasIncludingNonModalElements, ^{
    result = [FBApplication.fb_systemApplication.query respondsToSelector:@selector(includingNonModalElements)];
  });
  return result;
}

- (XCUIElementQuery *)fb_query
{
  return FBConfiguration.includeNonModalElements && self.class.fb_supportsNonModalElementsInclusion
    ? self.query.includingNonModalElements
    : self.query;
}

@end

@implementation XCPointerEvent (FBXcodeCompatibility)

+ (BOOL)fb_areKeyEventsSupported
{
  static BOOL isKbInputSupported = NO;
  static dispatch_once_t onceKbInputSupported;
  dispatch_once(&onceKbInputSupported, ^{
    isKbInputSupported = [XCPointerEvent.class respondsToSelector:@selector(keyboardEventForKeyCode:keyPhase:modifierFlags:offset:)];
  });
  return isKbInputSupported;
}

@end

NSInteger FBTestmanagerdVersion(void)
{
  static dispatch_once_t getTestmanagerdVersion;
  static NSInteger testmanagerdVersion;
  dispatch_once(&getTestmanagerdVersion, ^{
    id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [proxy _XCT_exchangeProtocolVersion:testmanagerdVersion reply:^(unsigned long long code) {
      testmanagerdVersion = (NSInteger) code;
      dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)));
  });
  return testmanagerdVersion;
}
