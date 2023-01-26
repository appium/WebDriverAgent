/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCAXClientProxy.h"

#import "FBXCAccessibilityElement.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "XCAXClient_iOS+FBSnapshotReqParams.h"
#import "XCUIDevice.h"

static id FBAXClient = nil;

@implementation FBXCAXClientProxy

+ (instancetype)sharedClient
{
  static FBXCAXClientProxy *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
    FBAXClient = [XCUIDevice.sharedDevice accessibilityInterface];
  });
  return instance;
}

- (BOOL)setAXTimeout:(NSTimeInterval)timeout error:(NSError **)error
{
  return [FBAXClient _setAXTimeout:timeout error:error];
}

- (id<FBXCElementSnapshot>)snapshotForElement:(id<FBXCAccessibilityElement>)element
                                   attributes:(NSArray<NSString *> *)attributes
                                     maxDepth:(nullable NSNumber *)maxDepth
                                        error:(NSError **)error
{
  NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:self.defaultParameters];
  if (nil != maxDepth) {
    parameters[FBSnapshotMaxDepthKey] = maxDepth;
  }

  id result = [FBAXClient requestSnapshotForElement:element
                                         attributes:attributes
                                         parameters:[parameters copy]
                                              error:error];
  id<FBXCElementSnapshot> snapshot = [result valueForKey:@"_rootElementSnapshot"];
  return nil == snapshot ? result : snapshot;
}

- (NSArray<id<FBXCAccessibilityElement>> *)activeApplications
{
  return [FBAXClient activeApplications];
}

- (id<FBXCAccessibilityElement>)systemApplication
{
  return [FBAXClient systemApplication];
}

- (NSDictionary *)defaultParameters
{
  return [FBAXClient defaultParameters];
}

- (void)notifyWhenNoAnimationsAreActiveForApplication:(XCUIApplication *)application
                                                reply:(void (^)(void))reply
{
  [FBAXClient notifyWhenNoAnimationsAreActiveForApplication:application reply:reply];
}

- (NSDictionary *)attributesForElement:(id<FBXCAccessibilityElement>)element
                            attributes:(NSArray *)attributes
{
  NSError *error = nil;
  NSDictionary* result = [FBAXClient attributesForElement:element
                                               attributes:attributes
                                                    error:&error];
  if (error) {
    [FBLogger logFmt:@"Cannot retrieve element attribute(s) %@. Original error: %@", attributes, error.description];
  }
  return result;
}

- (XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)pid
{
  return [[FBAXClient applicationProcessTracker] monitoredApplicationWithProcessIdentifier:pid];
}

@end
