/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCodeCompatibility.h"

#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "XCUIElementQuery.h"

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
  if (FBShouldUseOldAppWithPIDSelector) {
    return [self appWithPID:processID];
  }
  return [self applicationWithPID:processID];
}

- (void)fb_activate
{
  [self activate];
}

- (NSUInteger)fb_state
{
  return [[self valueForKey:@"state"] intValue];
}

@end


static BOOL FBShouldUseFirstMatchSelector = NO;
static dispatch_once_t onceFirstMatchToken;

@implementation XCUIElementQuery (FBCompatibility)

- (XCUIElement *)fb_firstMatch
{
  dispatch_once(&onceFirstMatchToken, ^{
    // Unfortunately, firstMatch property does not work properly if
    // the lookup is not executed in application context:
    // https://github.com/appium/appium/issues/10101
    //    FBShouldUseFirstMatchSelector = [self respondsToSelector:@selector(firstMatch)];
    FBShouldUseFirstMatchSelector = NO;
  });
  if (FBShouldUseFirstMatchSelector) {
    XCUIElement* result = self.firstMatch;
    return result.exists ? result : nil;
  }
  if (!self.element.exists) {
    return nil;
  }
  return self.allElementsBoundByAccessibilityElement.firstObject;
}

- (XCElementSnapshot *)fb_elementSnapshotForDebugDescription
{
  if ([self respondsToSelector:@selector(elementSnapshotForDebugDescription)]) {
    return [self elementSnapshotForDebugDescription];
  }
  if ([self respondsToSelector:@selector(elementSnapshotForDebugDescriptionWithNoMatchesMessage:)]) {
    return [self elementSnapshotForDebugDescriptionWithNoMatchesMessage:nil];
  }
  @throw [[FBErrorBuilder.builder withDescription:@"Cannot retrieve element snapshots for debug description. Please contact Appium developers"] build];
  return nil;
}

@end


@implementation XCUIElement (FBCompatibility)

- (void)fb_nativeResolve
{
  if ([self respondsToSelector:@selector(resolve)]) {
    [self resolve];
    return;
  }
  if ([self respondsToSelector:@selector(resolveOrRaiseTestFailure)]) {
    @try {
      [self resolveOrRaiseTestFailure];
    } @catch (NSException *e) {
      [FBLogger logFmt:@"Failure while resolving '%@': %@", self.description, e.reason];
    }
    return;
  }
  @throw [[FBErrorBuilder.builder withDescription:@"Cannot resolve elements. Please contact Appium developers"] build];
}

@end
