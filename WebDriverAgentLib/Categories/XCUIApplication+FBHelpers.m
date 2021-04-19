/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBHelpers.h"

#import "XCElementSnapshot.h"
#import "FBElementTypeTransformer.h"
#import "FBKeyboard.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBActiveAppDetectionPoint.h"
#import "FBXCodeCompatibility.h"
#import "FBXPath.h"
#import "FBXCTestDaemonsProxy.h"
#import "FBXCAXClientProxy.h"
#import "XCAccessibilityElement.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"

const static NSTimeInterval FBMinimumAppSwitchWait = 3.0;
static NSString* const FBUnknownBundleId = @"unknown";


@implementation XCUIApplication (FBHelpers)

- (BOOL)fb_waitForAppElement:(NSTimeInterval)timeout
{
  __block BOOL canDetectAxElement = YES;
  int currentProcessIdentifier = self.accessibilityElement.processIdentifier;
  BOOL result = [[[FBRunLoopSpinner new]
           timeout:timeout]
          spinUntilTrue:^BOOL{
    XCAccessibilityElement *currentAppElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
    canDetectAxElement = nil != currentAppElement;
    if (!canDetectAxElement) {
      return YES;
    }
    return currentAppElement.processIdentifier == currentProcessIdentifier;
  }];
  return canDetectAxElement
    ? result
    : [self waitForExistenceWithTimeout:timeout];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)fb_appsInfoWithAxElements:(NSArray<XCAccessibilityElement *> *)axElements
{
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  for (XCAccessibilityElement *axElement in axElements) {
    NSMutableDictionary<NSString *, id> *appInfo = [NSMutableDictionary dictionary];
    pid_t pid = axElement.processIdentifier;
    appInfo[@"pid"] = @(pid);
    __block NSString *bundleId = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [proxy _XCT_requestBundleIDForPID:pid
                                reply:^(NSString *bundleID, NSError *error) {
                                  if (nil == error) {
                                    bundleId = bundleID;
                                  } else {
                                    [FBLogger logFmt:@"Cannot request the bundle ID for process ID %@: %@", @(pid), error.description];
                                  }
                                  dispatch_semaphore_signal(sem);
                                }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    appInfo[@"bundleId"] = bundleId ?: FBUnknownBundleId;
    [result addObject:appInfo.copy];
  }
  return result.copy;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)fb_activeAppsInfo
{
  return [self fb_appsInfoWithAxElements:[FBXCAXClientProxy.sharedClient activeApplications]];
}

- (BOOL)fb_deactivateWithDuration:(NSTimeInterval)duration error:(NSError **)error
{
  if(![[XCUIDevice sharedDevice] fb_goToHomescreenWithError:error]) {
    return NO;
  }
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:MAX(duration, FBMinimumAppSwitchWait)]];
  [self fb_activate];
  return YES;
}

- (NSDictionary *)fb_tree
{
  XCElementSnapshot *snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : [self fb_snapshotWithAllAttributesAndMaxDepth:nil];
  return [self.class dictionaryForElement:snapshot recursive:YES];
}

- (NSDictionary *)fb_accessibilityTree
{
  XCElementSnapshot *snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : [self fb_snapshotWithAllAttributesAndMaxDepth:nil];
  return [self.class accessibilityInfoForElement:snapshot];
}

+ (NSDictionary *)dictionaryForElement:(XCElementSnapshot *)snapshot recursive:(BOOL)recursive
{
  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
  info[@"type"] = [FBElementTypeTransformer shortStringWithElementType:snapshot.elementType];
  info[@"rawIdentifier"] = FBValueOrNull([snapshot.identifier isEqual:@""] ? nil : snapshot.identifier);
  info[@"name"] = FBValueOrNull(snapshot.wdName);
  info[@"value"] = FBValueOrNull(snapshot.wdValue);
  info[@"label"] = FBValueOrNull(snapshot.wdLabel);
  // It is mandatory to replace all Infinity values with zeroes to avoid JSON parsing
  // exceptions like https://github.com/facebook/WebDriverAgent/issues/639#issuecomment-314421206
  // caused by broken element dimensions returned by XCTest
  info[@"rect"] = FBwdRectNoInf(snapshot.wdRect);
  info[@"frame"] = NSStringFromCGRect(snapshot.wdFrame);
  info[@"isEnabled"] = [@([snapshot isWDEnabled]) stringValue];
  info[@"isVisible"] = [@([snapshot isWDVisible]) stringValue];
  info[@"isAccessible"] = [@([snapshot isWDAccessible]) stringValue];
#if TARGET_OS_TV
  info[@"isFocused"] = [@([snapshot isWDFocused]) stringValue];
#endif

  if (!recursive) {
    return info.copy;
  }

  NSArray *childElements = snapshot.children;
  if ([childElements count]) {
    info[@"children"] = [[NSMutableArray alloc] init];
    for (XCElementSnapshot *childSnapshot in childElements) {
      [info[@"children"] addObject:[self dictionaryForElement:childSnapshot recursive:YES]];
    }
  }
  return info;
}

+ (NSDictionary *)accessibilityInfoForElement:(XCElementSnapshot *)snapshot
{
  BOOL isAccessible = [snapshot isWDAccessible];
  BOOL isVisible = [snapshot isWDVisible];

  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

  if (isAccessible) {
    if (isVisible) {
      info[@"value"] = FBValueOrNull(snapshot.wdValue);
      info[@"label"] = FBValueOrNull(snapshot.wdLabel);
    }
  } else {
    NSMutableArray *children = [[NSMutableArray alloc] init];
    for (XCElementSnapshot *childSnapshot in snapshot.children) {
      NSDictionary *childInfo = [self accessibilityInfoForElement:childSnapshot];
      if ([childInfo count]) {
        [children addObject: childInfo];
      }
    }
    if ([children count]) {
      info[@"children"] = [children copy];
    }
  }
  if ([info count]) {
    info[@"type"] = [FBElementTypeTransformer shortStringWithElementType:snapshot.elementType];
    info[@"rawIdentifier"] = FBValueOrNull([snapshot.identifier isEqual:@""] ? nil : snapshot.identifier);
    info[@"name"] = FBValueOrNull(snapshot.wdName);
  } else {
    return nil;
  }
  return info;
}

- (NSString *)fb_xmlRepresentation
{
  return [FBXPath xmlStringWithRootElement:self excludingAttributes:nil];
}

- (NSString *)fb_xmlRepresentationWithoutAttributes:(NSArray<NSString *> *)excludedAttributes
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
  return [FBXPath xmlStringWithRootElement:self excludingAttributes:excludedAttributes];
#pragma clang diagnostic pop
}

- (NSString *)fb_descriptionRepresentation
{
  NSMutableArray<NSString *> *childrenDescriptions = [NSMutableArray array];
  for (XCUIElement *child in [self.fb_query childrenMatchingType:XCUIElementTypeAny].allElementsBoundByAccessibilityElement) {
    [childrenDescriptions addObject:child.debugDescription];
  }
  // debugDescription property of XCUIApplication instance shows descendants addresses in memory
  // instead of the actual information about them, however the representation works properly
  // for all descendant elements
  return (0 == childrenDescriptions.count) ? self.debugDescription : [childrenDescriptions componentsJoinedByString:@"\n\n"];
}

- (XCUIElement *)fb_activeElement
{
  return [[[self.fb_query descendantsMatchingType:XCUIElementTypeAny]
           matchingPredicate:[NSPredicate predicateWithFormat:@"hasKeyboardFocus == YES"]]
          fb_firstMatch];
}

#if TARGET_OS_TV
- (XCUIElement *)fb_focusedElement
{
  return [[[self.fb_query descendantsMatchingType:XCUIElementTypeAny]
           matchingPredicate:[NSPredicate predicateWithFormat:@"hasFocus == true"]]
          fb_firstMatch];
}
#endif

+ (NSInteger)fb_testmanagerdVersion
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

- (BOOL)fb_resetAuthorizationStatusForResource:(long long)resourceId error:(NSError **)error
{
  SEL selector = NSSelectorFromString(@"resetAuthorizationStatusForResource:");
  if (![self respondsToSelector:selector]) {
    return [[[FBErrorBuilder builder]
             withDescription:@"'resetAuthorizationStatusForResource' API is only supported for Xcode SDK 11.4 and later"]
            buildError:error];
  }
  NSMethodSignature *signature = [self methodSignatureForSelector:selector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
  [invocation setSelector:selector];
  [invocation setArgument:&resourceId atIndex:2]; // 0 and 1 are reserved
  [invocation invokeWithTarget:self];
  return YES;
}

- (BOOL)fb_dismissKeyboardWithKeyNames:(nullable NSArray<NSString *> *)keyNames
                                 error:(NSError **)error
{
  BOOL (^isKeyboardInvisible)(void) = ^BOOL(void) {
    return ![FBKeyboard waitUntilVisibleForApplication:self
                                               timeout:0
                                                 error:nil];
  };

  if (isKeyboardInvisible()) {
    // Short circuit if the keyboard is not visible
    return YES;
  }

#if TARGET_OS_TV
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonMenu];
#else
  NSArray<XCUIElement *> *(^findMatchingKeys)(NSPredicate *) = ^NSArray<XCUIElement *> *(NSPredicate * predicate) {
    NSPredicate *keysPredicate = [NSPredicate predicateWithFormat:@"elementType == %@", @(XCUIElementTypeKey)];
    XCUIElementQuery *parentView = [[self.keyboard descendantsMatchingType:XCUIElementTypeOther]
                                    containingPredicate:keysPredicate];
    return [[parentView childrenMatchingType:XCUIElementTypeAny]
            matchingPredicate:predicate].allElementsBoundByIndex;
  };

  if (nil != keyNames && keyNames.count > 0) {
    NSPredicate *searchPredicate = [NSPredicate predicateWithBlock:^BOOL(XCElementSnapshot *snapshot, NSDictionary *bindings) {
      if (snapshot.elementType != XCUIElementTypeKey && snapshot.elementType != XCUIElementTypeButton) {
        return NO;
      }

      return (nil != snapshot.identifier && [keyNames containsObject:snapshot.identifier])
        || (nil != snapshot.label && [keyNames containsObject:snapshot.label]);
    }];
    NSArray *matchedKeys = findMatchingKeys(searchPredicate);
    if (matchedKeys.count > 0) {
      for (XCUIElement *matchedKey in matchedKeys) {
        if (!matchedKey.exists) {
          continue;
        }

        [matchedKey fb_tapWithError:nil];
        if (isKeyboardInvisible()) {
          return YES;
        }
      }
    }
  }
  
  if ([UIDevice.currentDevice userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"elementType IN %@",
                                    @[@(XCUIElementTypeKey), @(XCUIElementTypeButton)]];
    NSArray *matchedKeys = findMatchingKeys(searchPredicate);
    if (matchedKeys.count > 0) {
      [matchedKeys[matchedKeys.count - 1] fb_tapWithError:nil];
    }
  }
#endif
  NSString *errorDescription = @"Did not know how to dismiss the keyboard. Try to dismiss it in the way supported by your application under test.";
  return [[[[FBRunLoopSpinner new]
            timeout:3]
           timeoutErrorMessage:errorDescription]
          spinUntilTrue:isKeyboardInvisible
          error:error];
}

@end
