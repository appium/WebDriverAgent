/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBConfiguration.h"

#import <UIKit/UIKit.h>

#include "TargetConditionals.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot.h"

NSString *const FB_ALERT_ACCEPT_ACTION = @"accept";
NSString *const FB_ALERT_DISMISS_ACTION = @"dismiss";
NSString *const FB_ALERT_NONE_ACTION = @"none";

static NSUInteger const DefaultStartingPort = 8100;
static NSUInteger const DefaultPortRange = 100;

static BOOL FBShouldUseTestManagerForVisibilityDetection = NO;
static BOOL FBShouldUseSingletonTestManager = YES;
static BOOL FBShouldUseCompactResponses = YES;
static NSString *FBAutoAlertAction = nil;
static NSString *FBElementResponseAttributes = @"type,label";
static NSUInteger FBMaxTypingFrequency = 60;

@implementation FBConfiguration

#pragma mark Public

+ (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

+ (void)disableAttributeKeyPathAnalysis
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableAttributeKeyPathAnalysis"];
}

+ (NSRange)bindingPortRange
{
  // 'WebDriverAgent --port 8080' can be passed via the arguments to the process
  if (self.bindingPortRangeFromArguments.location != NSNotFound) {
    return self.bindingPortRangeFromArguments;
  }

  // Existence of USE_PORT in the environment implies the port range is managed by the launching process.
  if (NSProcessInfo.processInfo.environment[@"USE_PORT"]) {
    return NSMakeRange([NSProcessInfo.processInfo.environment[@"USE_PORT"] integerValue] , 1);
  }

  return NSMakeRange(DefaultStartingPort, DefaultPortRange);
}

+ (BOOL)verboseLoggingEnabled
{
  return [NSProcessInfo.processInfo.environment[@"VERBOSE_LOGGING"] boolValue];
}

+ (void)setShouldUseTestManagerForVisibilityDetection:(BOOL)value
{
  FBShouldUseTestManagerForVisibilityDetection = value;
}

+ (BOOL)shouldUseTestManagerForVisibilityDetection
{
  return FBShouldUseTestManagerForVisibilityDetection;
}

+ (void)setShouldUseCompactResponses:(BOOL)value
{
  FBShouldUseCompactResponses = value;
}

+ (BOOL)shouldUseCompactResponses
{
  return FBShouldUseCompactResponses;
}

+ (void)setElementResponseAttributes:(NSString *)value
{
  FBElementResponseAttributes = value;
}

+ (NSString *)elementResponseAttributes
{
  return FBElementResponseAttributes;
}

+ (void)setMaxTypingFrequency:(NSUInteger)value
{
  FBMaxTypingFrequency = value;
}

+ (NSUInteger)maxTypingFrequency
{
  return FBMaxTypingFrequency;
}

+ (void)setShouldUseSingletonTestManager:(BOOL)value
{
  FBShouldUseSingletonTestManager = value;
}

+ (BOOL)shouldUseSingletonTestManager
{
  return FBShouldUseSingletonTestManager;
}

+ (BOOL)shouldLoadSnapshotWithAttributes {
  static BOOL shouldLoadSnapshotWithAttributes = NO;
  static dispatch_once_t shouldLoadSnapshotWithAttributesToken;
  dispatch_once(&shouldLoadSnapshotWithAttributesToken, ^{
    if ([XCElementSnapshot.class respondsToSelector:@selector(snapshotAttributesForElementSnapshotKeyPaths:)]) {
      shouldLoadSnapshotWithAttributes = YES;
    }
  });
  return shouldLoadSnapshotWithAttributes;
}

#pragma mark Private

+ (NSRange)bindingPortRangeFromArguments
{
  NSArray *arguments = NSProcessInfo.processInfo.arguments;
  NSUInteger index = [arguments indexOfObject:@"--port"];
  if (index == NSNotFound || index == arguments.count - 1) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSString *portNumberString = arguments[index + 1];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(port, 1);
}

+ (void)setAutoAlertAction:(NSString *)value
{
  FBAutoAlertAction = [value lowercaseString];
}

+ (NSString *)autoAlertAction
{
  return FBAutoAlertAction ?: FB_ALERT_NONE_ACTION;
}

@end
