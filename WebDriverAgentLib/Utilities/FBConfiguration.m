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
#import "FBXCodeCompatibility.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot.h"

static NSUInteger const DefaultStartingPort = 8100;
static NSUInteger const DefaultMjpegServerPort = 9100;
static NSUInteger const DefaultPortRange = 100;

static BOOL FBShouldUseTestManagerForVisibilityDetection = NO;
static BOOL FBShouldUseSingletonTestManager = YES;
static BOOL FBShouldUseCompactResponses = YES;
static BOOL FBShouldWaitForQuiescence = NO;
static NSString *FBElementResponseAttributes = @"type,label";
static NSUInteger FBMaxTypingFrequency = 60;
static NSUInteger FBMjpegServerScreenshotQuality = 25;
static NSUInteger FBMjpegServerFramerate = 10;
static NSUInteger FBScreenshotQuality = 1;

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
  if (NSProcessInfo.processInfo.environment[@"USE_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"USE_PORT"] length] > 0) {
    return NSMakeRange([NSProcessInfo.processInfo.environment[@"USE_PORT"] integerValue] , 1);
  }

  return NSMakeRange(DefaultStartingPort, DefaultPortRange);
}

+ (NSInteger)mjpegServerPort
{
  if (self.mjpegServerPortFromArguments != NSNotFound) {
    return self.mjpegServerPortFromArguments;
  }
  
  if (NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] length] > 0) {
    return [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] integerValue];
  }

  return DefaultMjpegServerPort;
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

+ (BOOL)shouldLoadSnapshotWithAttributes
{
  return [XCElementSnapshot fb_attributesForElementSnapshotKeyPathsSelector] != nil;
}

+ (BOOL)shouldWaitForQuiescence
{
  return FBShouldWaitForQuiescence;
}

+ (void)setShouldWaitForQuiescence:(BOOL)value
{
  FBShouldWaitForQuiescence = value;
}

+ (NSUInteger)mjpegServerFramerate
{
  return FBMjpegServerFramerate;
}

+ (void)setMjpegServerFramerate:(NSUInteger)framerate
{
  FBMjpegServerFramerate = framerate;
}

+ (NSUInteger)mjpegServerScreenshotQuality
{
  return FBMjpegServerScreenshotQuality;
}

+ (void)setMjpegServerScreenshotQuality:(NSUInteger)quality
{
  FBMjpegServerScreenshotQuality = quality;
}

+ (NSUInteger)screenshotQuality
{
  return FBScreenshotQuality;
}

+ (void)setScreenshotQuality:(NSUInteger)quality
{
  FBScreenshotQuality = quality;
}

#pragma mark Private

+ (NSString*)valueFromArguments: (NSArray<NSString *> *)arguments forKey: (NSString*)key
{
  NSUInteger index = [arguments indexOfObject:key];
  if (index == NSNotFound || index == arguments.count - 1) {
    return nil;
  }
  return arguments[index + 1];
}

+ (NSUInteger)mjpegServerPortFromArguments
{
  NSString *portNumberString = [self valueFromArguments: NSProcessInfo.processInfo.arguments
                                                 forKey: @"--mjpeg-server-port"];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSNotFound;
  }
  return port;
}

+ (NSRange)bindingPortRangeFromArguments
{
  NSString *portNumberString = [self valueFromArguments:NSProcessInfo.processInfo.arguments
                                                 forKey: @"--port"];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(port, 1);
}

@end
