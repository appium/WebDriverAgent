/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplication+FBHelpers.h"

#import "FBActiveAppDetectionPoint.h"
#import "FBElementTypeTransformer.h"
#import "FBKeyboard.h"
#import "FBLogger.h"
#import "FBExceptions.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRunLoopSpinner.h"
#import "FBXCodeCompatibility.h"
#import "FBXPath.h"
#import "FBXCAccessibilityElement.h"
#import "FBXCTestDaemonsProxy.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBXCAXClientProxy.h"
#import "FBXMLGenerationOptions.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIApplication.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElementQuery.h"

static NSString* const FBUnknownBundleId = @"unknown";

static NSString* const FBExclusionAttributeFrame = @"frame";
static NSString* const FBExclusionAttributeEnabled = @"enabled";
static NSString* const FBExclusionAttributeVisible = @"visible";
static NSString* const FBExclusionAttributeAccessible = @"accessible";
static NSString* const FBExclusionAttributeFocused = @"focused";
static NSString* const FBExclusionAttributePlaceholderValue = @"placeholderValue";


_Nullable id extractIssueProperty(id issue, NSString *propertyName) {
  SEL selector = NSSelectorFromString(propertyName);
  NSMethodSignature *methodSignature = [issue methodSignatureForSelector:selector];
  if (nil == methodSignature) {
    return nil;
  }
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  [invocation setSelector:selector];
  [invocation invokeWithTarget:issue];
  id __unsafe_unretained result;
  [invocation getReturnValue:&result];
  return result;
}

NSDictionary<NSString *, NSNumber *> *auditTypeNamesToValues(void) {
  static dispatch_once_t onceToken;
  static NSDictionary *result;
  dispatch_once(&onceToken, ^{
    // https://developer.apple.com/documentation/xctest/xcuiaccessibilityaudittype?language=objc
    result = @{
      @"XCUIAccessibilityAuditTypeAction": @(1UL << 32),
      @"XCUIAccessibilityAuditTypeAll": @(~0UL),
      @"XCUIAccessibilityAuditTypeContrast": @(1UL << 0),
      @"XCUIAccessibilityAuditTypeDynamicType": @(1UL << 16),
      @"XCUIAccessibilityAuditTypeElementDetection": @(1UL << 1),
      @"XCUIAccessibilityAuditTypeHitRegion": @(1UL << 2),
      @"XCUIAccessibilityAuditTypeParentChild": @(1UL << 33),
      @"XCUIAccessibilityAuditTypeSufficientElementDescription": @(1UL << 3),
      @"XCUIAccessibilityAuditTypeTextClipped": @(1UL << 17),
      @"XCUIAccessibilityAuditTypeTrait": @(1UL << 18),
    };
  });
  return result;
}

NSDictionary<NSNumber *, NSString *> *auditTypeValuesToNames(void) {
  static dispatch_once_t onceToken;
  static NSDictionary *result;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary *inverted = [NSMutableDictionary new];
    [auditTypeNamesToValues() enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSNumber *value, BOOL *stop) {
      inverted[value] = key;
    }];
    result = inverted.copy;
  });
  return result;
}

NSDictionary<NSString *, NSString *> *customExclusionAttributesMap(void) {
  static dispatch_once_t onceToken;
  static NSDictionary *result;
  dispatch_once(&onceToken, ^{
    result = @{
      FBExclusionAttributeVisible: FB_XCAXAIsVisibleAttributeName,
      FBExclusionAttributeAccessible: FB_XCAXAIsElementAttributeName,
    };
  });
  return result;
}

@implementation XCUIApplication (FBHelpers)

- (BOOL)fb_waitForAppElement:(NSTimeInterval)timeout
{
  __block BOOL canDetectAxElement = YES;
  int currentProcessIdentifier = [self.accessibilityElement processIdentifier];
  BOOL result = [[[FBRunLoopSpinner new]
           timeout:timeout]
          spinUntilTrue:^BOOL{
    id<FBXCAccessibilityElement> currentAppElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
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

+ (NSArray<NSDictionary<NSString *, id> *> *)fb_appsInfoWithAxElements:(NSArray<id<FBXCAccessibilityElement>> *)axElements
{
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  for (id<FBXCAccessibilityElement> axElement in axElements) {
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
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:MAX(duration, .0)]];
  [self activate];
  return YES;
}

- (NSDictionary *)fb_tree
{
  return [self fb_tree:nil];
}

- (NSDictionary *)fb_tree:(nullable NSSet<NSString *> *)excludedAttributes
{
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  return [self.class dictionaryForElement:snapshot
                                recursive:YES
                       excludedAttributes:excludedAttributes];
}

- (NSDictionary *)fb_accessibilityTree
{
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  return [self.class accessibilityInfoForElement:snapshot];
}

+ (NSDictionary *)dictionaryForElement:(id<FBXCElementSnapshot>)snapshot 
                             recursive:(BOOL)recursive
                    excludedAttributes:(nullable NSSet<NSString *> *)excludedAttributes
{
  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
  info[@"type"] = [FBElementTypeTransformer shortStringWithElementType:snapshot.elementType];
  info[@"rawIdentifier"] = FBValueOrNull([snapshot.identifier isEqual:@""] ? nil : snapshot.identifier);
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  info[@"name"] = FBValueOrNull(wrappedSnapshot.wdName);
  info[@"value"] = FBValueOrNull(wrappedSnapshot.wdValue);
  info[@"label"] = FBValueOrNull(wrappedSnapshot.wdLabel);
  info[@"rect"] = wrappedSnapshot.wdRect;
  
  // Define the base attribute blocks that apply to all elements.
  NSDictionary<NSString *, NSString * (^)(void)> *baseAttributeBlocks = @{
      FBExclusionAttributeFrame: ^{
          return NSStringFromCGRect(wrappedSnapshot.wdFrame);
      },
      FBExclusionAttributeEnabled: ^{
          return [@([wrappedSnapshot isWDEnabled]) stringValue];
      },
      FBExclusionAttributeVisible: ^{
          return [@([wrappedSnapshot isWDVisible]) stringValue];
      },
      FBExclusionAttributeAccessible: ^{
          return [@([wrappedSnapshot isWDAccessible]) stringValue];
      },
      FBExclusionAttributeFocused: ^{
          return [@([wrappedSnapshot isWDFocused]) stringValue];
      }
  };
  
  NSMutableDictionary<NSString *, NSString *(^)(void)> *attributeBlocks;
  
  // Add placeholderValue only for elements where it is meaningful (e.g., text input fields).
  switch (snapshot.elementType) {
      case XCUIElementTypeTextField:
      case XCUIElementTypeSecureTextField:
      case XCUIElementTypeSearchField: {
          // Copy base attributes to a mutable dictionary so we can add placeholderValue.
          attributeBlocks = [baseAttributeBlocks mutableCopy];
          attributeBlocks[FBExclusionAttributePlaceholderValue] = ^{
            return (NSString *)FBValueOrNull(wrappedSnapshot.wdPlaceholderValue);
        };
          break;
      }
      default:
          // Use the base attributes as-is if placeholderValue is not applicable.
          attributeBlocks = [baseAttributeBlocks copy];
          break;
  }

  NSSet *nonPrefixedKeys = [NSSet setWithObjects:FBExclusionAttributeFrame, FBExclusionAttributePlaceholderValue, nil];

  for (NSString *key in attributeBlocks) {
      if (excludedAttributes == nil || ![excludedAttributes containsObject:key]) {
          NSString *value = ((NSString * (^)(void))attributeBlocks[key])();
          if ([nonPrefixedKeys containsObject:key]) {
              info[key] = value;
          } else {
              info[[NSString stringWithFormat:@"is%@", [key capitalizedString]]] = value;
          }
      }
  }

  if (!recursive) {
    return info.copy;
  }

  NSArray *childElements = snapshot.children;
  if ([childElements count]) {
    info[@"children"] = [[NSMutableArray alloc] init];
    for (id<FBXCElementSnapshot> childSnapshot in childElements) {
      @autoreleasepool {
        [info[@"children"] addObject:[self dictionaryForElement:childSnapshot
                                                      recursive:YES
                                             excludedAttributes:excludedAttributes]];
      }
    }
  }
  return info;
}

+ (NSDictionary *)accessibilityInfoForElement:(id<FBXCElementSnapshot>)snapshot
{
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  BOOL isAccessible = [wrappedSnapshot isWDAccessible];
  BOOL isVisible = [wrappedSnapshot isWDVisible];

  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

  if (isAccessible) {
    if (isVisible) {
      info[@"value"] = FBValueOrNull(wrappedSnapshot.wdValue);
      info[@"label"] = FBValueOrNull(wrappedSnapshot.wdLabel);
    }
  } else {
    NSMutableArray *children = [[NSMutableArray alloc] init];
    for (id<FBXCElementSnapshot> childSnapshot in snapshot.children) {
      @autoreleasepool {
        NSDictionary *childInfo = [self accessibilityInfoForElement:childSnapshot];
        if ([childInfo count]) {
          [children addObject: childInfo];
        }
      }
    }
    if ([children count]) {
      info[@"children"] = [children copy];
    }
  }
  if ([info count]) {
    info[@"type"] = [FBElementTypeTransformer shortStringWithElementType:snapshot.elementType];
    info[@"rawIdentifier"] = FBValueOrNull([snapshot.identifier isEqual:@""] ? nil : snapshot.identifier);
    info[@"name"] = FBValueOrNull(wrappedSnapshot.wdName);
  } else {
    return nil;
  }
  return info;
}

- (NSString *)fb_xmlRepresentation
{
  return [self fb_xmlRepresentationWithOptions:nil];
}

- (NSString *)fb_xmlRepresentationWithOptions:(FBXMLGenerationOptions *)options
{
  return [FBXPath xmlStringWithRootElement:self options:options];
}

- (NSString *)fb_descriptionRepresentation
{
  NSMutableArray<NSString *> *childrenDescriptions = [NSMutableArray array];
  for (XCUIElement *child in [self.fb_query childrenMatchingType:XCUIElementTypeAny].allElementsBoundByIndex) {
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
    NSPredicate *searchPredicate = [NSPredicate predicateWithBlock:^BOOL(id<FBXCElementSnapshot> snapshot, NSDictionary *bindings) {
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

        [matchedKey tap];
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
      [matchedKeys[matchedKeys.count - 1] tap];
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

- (NSArray<NSDictionary<NSString *, NSString*> *> *)fb_performAccessibilityAuditWithAuditTypesSet:(NSSet<NSString *> *)auditTypes
                                                                                            error:(NSError **)error;
{
  uint64_t numTypes = 0;
  NSDictionary *namesMap = auditTypeNamesToValues();
  for (NSString *value in auditTypes) {
    NSNumber *typeValue = namesMap[value];
    if (nil == typeValue) {
      NSString *reason = [NSString stringWithFormat:@"Audit type value '%@' is not known. Only the following audit types are supported: %@", value, namesMap.allKeys];
      @throw [NSException exceptionWithName:FBInvalidArgumentException reason:reason userInfo:@{}];
    }
    numTypes |= [typeValue unsignedLongLongValue];
  }
  return [self fb_performAccessibilityAuditWithAuditTypes:numTypes error:error];
}

- (NSArray<NSDictionary<NSString *, NSString*> *> *)fb_performAccessibilityAuditWithAuditTypes:(uint64_t)auditTypes
                                                                                         error:(NSError **)error;
{
  SEL selector = NSSelectorFromString(@"performAccessibilityAuditWithAuditTypes:issueHandler:error:");
  if (![self respondsToSelector:selector]) {
    [[[FBErrorBuilder alloc]
      withDescription:@"Accessibility audit is only supported since iOS 17/Xcode 15"]
     buildError:error];
    return nil;
  }

  // These custom attributes could take too long to fetch, thus excluded
  NSSet *customAttributesToExclude = [NSSet setWithArray:[customExclusionAttributesMap() allKeys]];
  NSMutableArray<NSDictionary *> *resultArray = [NSMutableArray array];
  NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  [invocation setSelector:selector];
  [invocation setArgument:&auditTypes atIndex:2];
  BOOL (^issueHandler)(id) = ^BOOL(id issue) {
    @autoreleasepool {
      NSString *auditType = @"";
      NSDictionary *valuesToNamesMap = auditTypeValuesToNames();
      NSNumber *auditTypeValue = [issue valueForKey:@"auditType"];
      if (nil != auditTypeValue) {
        auditType = valuesToNamesMap[auditTypeValue] ?: [auditTypeValue stringValue];
      }
      
      id extractedElement = extractIssueProperty(issue, @"element");
      
      id<FBXCElementSnapshot> elementSnapshot = [extractedElement fb_cachedSnapshot] ?: [extractedElement fb_standardSnapshot];
      NSDictionary *elementAttributes = elementSnapshot
      ? [self.class dictionaryForElement:elementSnapshot
                               recursive:NO
                      excludedAttributes:customAttributesToExclude]
      : @{};
      
      [resultArray addObject:@{
        @"detailedDescription": extractIssueProperty(issue, @"detailedDescription") ?: @"",
        @"compactDescription": extractIssueProperty(issue, @"compactDescription") ?: @"",
        @"auditType": auditType,
        @"element": [extractedElement description] ?: @"",
        @"elementDescription": [extractedElement debugDescription] ?: @"",
        @"elementAttributes": elementAttributes ?: @{},
      }];
      return YES;
    }
  };
  [invocation setArgument:&issueHandler atIndex:3];
  [invocation setArgument:&error atIndex:4];
  [invocation invokeWithTarget:self];
  BOOL isSuccessful;
  [invocation getReturnValue:&isSuccessful];
  return isSuccessful ? resultArray.copy : nil;
}

+ (instancetype)fb_activeApplication
{
  return [self fb_activeApplicationWithDefaultBundleId:nil];
}

+ (NSArray<XCUIApplication *> *)fb_activeApplications
{
  NSArray<id<FBXCAccessibilityElement>> *activeApplicationElements = [FBXCAXClientProxy.sharedClient activeApplications];
  NSMutableArray<XCUIApplication *> *result = [NSMutableArray array];
  if (activeApplicationElements.count > 0) {
    for (id<FBXCAccessibilityElement> applicationElement in activeApplicationElements) {
      XCUIApplication *app = [XCUIApplication fb_applicationWithPID:applicationElement.processIdentifier];
      if (nil != app) {
        [result addObject:app];
      }
    }
  }
  return result.count > 0 ? result.copy : @[self.class.fb_systemApplication];
}

+ (instancetype)fb_activeApplicationWithDefaultBundleId:(nullable NSString *)bundleId
{
  NSArray<id<FBXCAccessibilityElement>> *activeApplicationElements = [FBXCAXClientProxy.sharedClient activeApplications];
  id<FBXCAccessibilityElement> activeApplicationElement = nil;
  id<FBXCAccessibilityElement> currentElement = nil;
  if (nil != bundleId) {
    currentElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
    if (nil != currentElement) {
      NSArray<NSDictionary *> *appInfos = [self fb_appsInfoWithAxElements:@[currentElement]];
      [FBLogger logFmt:@"Detected on-screen application: %@", appInfos.firstObject[@"bundleId"]];
      if ([[appInfos.firstObject objectForKey:@"bundleId"] isEqualToString:(id)bundleId]) {
        activeApplicationElement = currentElement;
      }
    }
  }
  if (nil == activeApplicationElement && activeApplicationElements.count > 1) {
    if (nil != bundleId) {
      NSArray<NSDictionary *> *appInfos = [self fb_appsInfoWithAxElements:activeApplicationElements];
      NSMutableArray<NSString *> *bundleIds = [NSMutableArray array];
      for (NSDictionary *appInfo in appInfos) {
        [bundleIds addObject:(NSString *)appInfo[@"bundleId"]];
      }
      [FBLogger logFmt:@"Detected system active application(s): %@", bundleIds];
      // Try to select the desired application first
      for (NSUInteger appIdx = 0; appIdx < appInfos.count; appIdx++) {
        if ([[[appInfos objectAtIndex:appIdx] objectForKey:@"bundleId"] isEqualToString:(id)bundleId]) {
          activeApplicationElement = [activeApplicationElements objectAtIndex:appIdx];
          break;
        }
      }
    }
    // Fall back to the "normal" algorithm if the desired application is either
    // not set or is not active
    if (nil == activeApplicationElement) {
      if (nil == currentElement) {
        currentElement = FBActiveAppDetectionPoint.sharedInstance.axElement;
      }
      if (nil == currentElement) {
        [FBLogger log:@"Cannot precisely detect the current application. Will use the system's recently active one"];
        if (nil == bundleId) {
          [FBLogger log:@"Consider changing the 'defaultActiveApplication' setting to the bundle identifier of the desired application under test"];
        }
      } else {
        for (id<FBXCAccessibilityElement> appElement in activeApplicationElements) {
          if (appElement.processIdentifier == currentElement.processIdentifier) {
            activeApplicationElement = appElement;
            break;
          }
        }
      }
    }
  }

  if (nil != activeApplicationElement) {
    XCUIApplication *application = [XCUIApplication fb_applicationWithPID:activeApplicationElement.processIdentifier];
    if (nil != application) {
      return application;
    }
    [FBLogger log:@"Cannot translate the active process identifier into an application object"];
  }

  if (activeApplicationElements.count > 0) {
    [FBLogger logFmt:@"Getting the most recent active application (out of %@ total items)", @(activeApplicationElements.count)];
    for (id<FBXCAccessibilityElement> appElement in activeApplicationElements) {
      XCUIApplication *application = [XCUIApplication fb_applicationWithPID:appElement.processIdentifier];
      if (nil != application) {
        return application;
      }
    }
  }

  [FBLogger log:@"Cannot retrieve any active applications. Assuming the system application is the active one"];
  return [self fb_systemApplication];
}

+ (instancetype)fb_systemApplication
{
  return [self fb_applicationWithPID:
                           [[FBXCAXClientProxy.sharedClient systemApplication] processIdentifier]];
}

+ (instancetype)fb_applicationWithPID:(pid_t)processID
{
  return [FBXCAXClientProxy.sharedClient monitoredApplicationWithProcessIdentifier:processID];
}

+ (BOOL)fb_switchToSystemApplicationWithError:(NSError **)error
{
  XCUIApplication *systemApp = self.fb_systemApplication;
  @try {
    if (!systemApp.running) {
      [systemApp launch];
    } else {
      [systemApp activate];
    }
  } @catch (NSException *e) {
    return [[[FBErrorBuilder alloc]
             withDescription:nil == e ? @"Cannot open the home screen" : e.reason]
            buildError:error];
  }
  return [[[[FBRunLoopSpinner new]
            timeout:5]
           timeoutErrorMessage:@"Timeout waiting until the home screen is visible"]
          spinUntilTrue:^BOOL{
    return [systemApp fb_isSameAppAs:self.fb_activeApplication];
  }
          error:error];
}

- (BOOL)fb_isSameAppAs:(nullable XCUIApplication *)otherApp
{
  if (nil == otherApp) {
    return NO;
  }
  return self == otherApp || [self.bundleID isEqualToString:(NSString *)otherApp.bundleID];
}

@end
