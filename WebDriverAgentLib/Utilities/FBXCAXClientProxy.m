/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCAXClientProxy.h"

#import "FBXCAccessibilityElement.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "XCAXClient_iOS+FBSnapshotReqParams.h"
#import "XCUIDevice.h"
#import "XCUIApplication.h"

static id FBAXClient = nil;

@interface FBXCAXClientProxy ()

@property (nonatomic) NSMutableDictionary<NSNumber *, XCUIApplication *> *appsCache;

@end

@implementation FBXCAXClientProxy

+ (instancetype)sharedClient
{
  static FBXCAXClientProxy *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
    instance.appsCache = [NSMutableDictionary dictionary];
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
                                      inDepth:(BOOL)inDepth
                                        error:(NSError **)error
{
  NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:self.defaultParameters];
  if (!inDepth) {
    parameters[FBSnapshotMaxDepthKey] = @1;
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
                                 error:(NSError**)error;
{
  return [FBAXClient attributesForElement:element
                               attributes:attributes
                                    error:error];
}

- (XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)pid
{
  NSMutableSet *terminatedAppIds = [NSMutableSet set];
  for (NSNumber *appPid in self.appsCache) {
    if (![self.appsCache[appPid] running]) {
      [terminatedAppIds addObject:appPid];
    }
  }
  for (NSNumber *appPid in terminatedAppIds) {
    [self.appsCache removeObjectForKey:appPid];
  }

  XCUIApplication *result = [self.appsCache objectForKey:@(pid)];
  if (nil != result) {
    return result;
  }

  XCUIApplication *app = [[FBAXClient applicationProcessTracker]
                          monitoredApplicationWithProcessIdentifier:pid];
  if (nil == app) {
    return nil;
  }
  [self.appsCache setObject:app forKey:@(pid)];
  return app;
}

@end
