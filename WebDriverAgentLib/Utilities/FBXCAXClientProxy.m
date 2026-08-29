/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCAXClientProxy.h"

#import "CDStructures.h"
#import "FBXCAccessibilityElement.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "XCAXClient_iOS+FBSnapshotReqParams.h"
#import "XCUIDevice.h"
#import "XCUIApplication.h"

static id FBAXClient = nil;

// Guards -withAXTimeout:do:'s save/set/restore of the process-wide AXTimeout global.
static NSRecursiveLock *FBAXTimeoutLock(void)
{
  static NSRecursiveLock *lock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    lock = [NSRecursiveLock new];
  });
  return lock;
}

// Guards +withXPCRequestTimeout:do:'s save/set/restore of the process-wide XPC request timeout global.
static NSRecursiveLock *FBXPCRequestTimeoutLock(void)
{
  static NSRecursiveLock *lock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    lock = [NSRecursiveLock new];
  });
  return lock;
}

// Guards +withApplicationStateTimeout:do:'s save/set/restore of the process-wide application-state timeout global.
static NSRecursiveLock *FBApplicationStateTimeoutLock(void)
{
  static NSRecursiveLock *lock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    lock = [NSRecursiveLock new];
  });
  return lock;
}

@interface FBXCAXClientProxy ()

@property (nonatomic) NSMutableDictionary<NSNumber *, XCUIApplication *> *appsCache;
@property (nonatomic, nullable) id<FBXCAccessibilityElement> cachedSystemApplication;

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

- (BOOL)withAXTimeout:(NSTimeInterval)timeout do:(void (^)(void))block error:(NSError **)error
{
  NSRecursiveLock *lock = FBAXTimeoutLock();
  [lock lock];
  @try {
    NSTimeInterval previousTimeout = [FBAXClient AXTimeout];
    NSError *setError;
    if (![FBAXClient _setAXTimeout:timeout error:&setError]) {
      [FBLogger logFmt:@"Failed to set AXTimeout to %@: %@", @(timeout), setError];
      if (nil != error) {
        *error = setError;
      }
      return NO;
    }
    NSTimeInterval startTime = NSProcessInfo.processInfo.systemUptime;
    BOOL completedInTime = NO;
    @try {
      block();
      completedInTime = (NSProcessInfo.processInfo.systemUptime - startTime) < timeout;
    } @finally {
      NSError *restoreError;
      if (![FBAXClient _setAXTimeout:previousTimeout error:&restoreError]) {
        [FBLogger logFmt:@"Failed to restore AXTimeout to %@: %@", @(previousTimeout), restoreError];
        if (nil != error) {
          *error = restoreError;
        }
      }
    }
    return completedInTime;
  } @finally {
    [lock unlock];
  }
}

+ (BOOL)withXPCRequestTimeout:(NSTimeInterval)timeout do:(void (^)(void))block
{
  NSRecursiveLock *lock = FBXPCRequestTimeoutLock();
  [lock lock];
  @try {
    NSTimeInterval previousTimeout = _XCTXPCRequestTimeout();
    _XCTSetXPCRequestTimeout(timeout);
    NSTimeInterval startTime = NSProcessInfo.processInfo.systemUptime;
    BOOL completedInTime = NO;
    @try {
      block();
      completedInTime = (NSProcessInfo.processInfo.systemUptime - startTime) < timeout;
    } @finally {
      _XCTSetXPCRequestTimeout(previousTimeout);
    }
    return completedInTime;
  } @finally {
    [lock unlock];
  }
}

+ (BOOL)withApplicationStateTimeout:(NSTimeInterval)timeout do:(void (^)(void))block
{
  NSRecursiveLock *lock = FBApplicationStateTimeoutLock();
  [lock lock];
  @try {
    NSTimeInterval previousTimeout = _XCTApplicationStateTimeout();
    _XCTSetApplicationStateTimeout(timeout);
    NSTimeInterval startTime = NSProcessInfo.processInfo.systemUptime;
    BOOL completedInTime = NO;
    @try {
      block();
      completedInTime = (NSProcessInfo.processInfo.systemUptime - startTime) < timeout;
    } @finally {
      _XCTSetApplicationStateTimeout(previousTimeout);
    }
    return completedInTime;
  } @finally {
    [lock unlock];
  }
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
  @synchronized (self) {
    if (nil == self.cachedSystemApplication) {
      // The system application's identity cannot change without it being killed,
      // which takes WDA down with it, so it is safe to cache it forever.
      self.cachedSystemApplication = [FBAXClient systemApplication];
    }
    return self.cachedSystemApplication;
  }
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

- (void)notifyWhenEventLoopIsIdleForApplication:(XCUIApplication *)application
                                           reply:(void (^)(id _Nullable result, NSError * _Nullable error))reply
{
  [FBAXClient notifyWhenEventLoopIsIdleForApplication:application reply:reply];
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
  @synchronized (self) {
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
}

@end
