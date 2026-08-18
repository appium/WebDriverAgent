/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCAXClient_iOS+FBSnapshotReqParams.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBXCAccessibilityElement.h"
#import "FBXCAXClientProxy.h"
#import "XCUIApplication.h"

/**
 Available parameters with their default values for XCTest:
  @"maxChildren" : (int)2147483647
  @"traverseFromParentsToChildren" : YES
  @"maxArrayCount" : (int)2147483647
  @"snapshotKeyHonorModalViews" : NO
  @"maxDepth" : (int)2147483647
 */
NSString *const FBSnapshotMaxDepthKey = @"maxDepth";
NSString *const FBSnapshotMaxChildrenKey = @"maxChildren";

static id (*original_defaultParameters)(id, SEL);
static id (*original_snapshotParameters)(id, SEL);
static NSDictionary *defaultRequestParameters;
static NSDictionary *defaultAdditionalRequestParameters;
static NSMutableDictionary *customRequestParameters;

void FBSetCustomParameterForElementSnapshot (NSString *name, id value)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    customRequestParameters = [NSMutableDictionary new];
  });
  customRequestParameters[name] = value;
}

id FBGetCustomParameterForElementSnapshot (NSString *name)
{
  return customRequestParameters[name];
}

static id swizzledDefaultParameters(id self, SEL _cmd)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultRequestParameters = original_defaultParameters(self, _cmd);
  });
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:defaultRequestParameters];
  [result addEntriesFromDictionary:defaultAdditionalRequestParameters ?: @{}];
  [result addEntriesFromDictionary:customRequestParameters ?: @{}];
  return result.copy;
}

static id swizzledSnapshotParameters(id self, SEL _cmd)
{
  NSDictionary *result = original_snapshotParameters(self, _cmd);
  defaultAdditionalRequestParameters = result;
  return result;
}

static id (*original_requestSnapshotForElement)(id, SEL, id, id, id, NSError **);

// pid -> last-unresponsive-at. XCTest retries a failed snapshot request several
// times in a row; this lets retries fail fast within `timeout` of the last check
// instead of each re-running the full wait.
static NSMutableDictionary<NSNumber *, NSDate *> *unresponsiveApplicationPids;
static NSObject *unresponsiveApplicationPidsLock;

static NSError *FBBuildUnresponsiveApplicationError(int pid, NSTimeInterval timeout)
{
  // https://github.com/appium/WebDriverAgent/issues/1210
  NSString *description = [NSString stringWithFormat:
    @"The application with process identifier %d did not confirm its main run loop is "
     @"responsive within %.1f second(s) and is likely in an unresponsive state. "
     @"Aborting the accessibility snapshot request instead of risking an indefinite "
     @"hang.",
    pid, timeout];
  [FBLogger logFmt:@"%@", description];
  NSError *error;
  [[[FBErrorBuilder builder] withDescription:description] buildError:&error];
  return error;
}

// Guards -[XCAXClient_iOS requestSnapshotForElement:...] against hanging forever
// on an unresponsive app (#1210). If accessibilityDeadline > 0, checks run loop
// responsiveness first and aborts with an error instead of risking an unbounded
// wait; otherwise falls through to the original, unbounded behavior.
static id swizzledRequestSnapshotForElement(id self, SEL _cmd, id element, id attributes, id parameters, NSError **error)
{
  NSTimeInterval timeout = FBConfiguration.sharedInstance.accessibilityDeadline;
  if (timeout < DBL_EPSILON) {
    return original_requestSnapshotForElement(self, _cmd, element, attributes, parameters, error);
  }

  int pid = [(id<FBXCAccessibilityElement>)element processIdentifier];
  XCUIApplication *application = [FBXCAXClientProxy.sharedClient monitoredApplicationWithProcessIdentifier:pid];
  if (nil == application) {
    // Nothing to confirm responsiveness for (e.g. the system element) - fall
    // through to the original behavior.
    return original_requestSnapshotForElement(self, _cmd, element, attributes, parameters, error);
  }

  NSNumber *pidKey = @(pid);
  @synchronized (unresponsiveApplicationPidsLock) {
    NSDate *markedUnresponsiveAt = unresponsiveApplicationPids[pidKey];
    if (nil != markedUnresponsiveAt && -markedUnresponsiveAt.timeIntervalSinceNow < timeout) {
      if (nil != error) {
        *error = FBBuildUnresponsiveApplicationError(pid, timeout);
      }
      return nil;
    }
  }

  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  __block BOOL isResponsive = NO;
  [FBXCAXClientProxy.sharedClient notifyWhenEventLoopIsIdleForApplication:application
                                                                     reply:^(id result, NSError *idleError) {
    isResponsive = (nil == idleError);
    dispatch_semaphore_signal(sem);
  }];
  BOOL didReplyInTime = 0 == dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
  if (didReplyInTime && isResponsive) {
    @synchronized (unresponsiveApplicationPidsLock) {
      [unresponsiveApplicationPids removeObjectForKey:pidKey];
    }
    return original_requestSnapshotForElement(self, _cmd, element, attributes, parameters, error);
  }

  @synchronized (unresponsiveApplicationPidsLock) {
    unresponsiveApplicationPids[pidKey] = [NSDate date];
  }
  if (nil != error) {
    *error = FBBuildUnresponsiveApplicationError(pid, timeout);
  }
  return nil;
}

@implementation XCAXClient_iOS (FBSnapshotReqParams)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

+ (void)load
{
  unresponsiveApplicationPids = [NSMutableDictionary new];
  unresponsiveApplicationPidsLock = [NSObject new];

  Method original_defaultParametersMethod = class_getInstanceMethod(self.class, @selector(defaultParameters));
  IMP swizzledDefaultParametersImp = (IMP)swizzledDefaultParameters;
  original_defaultParameters = (id (*)(id, SEL)) method_setImplementation(original_defaultParametersMethod, swizzledDefaultParametersImp);

  Method original_snapshotParametersMethod = class_getInstanceMethod(NSClassFromString(@"XCTElementQuery"), NSSelectorFromString(@"snapshotParameters"));
  IMP swizzledSnapshotParametersImp = (IMP)swizzledSnapshotParameters;
  original_snapshotParameters = (id (*)(id, SEL)) method_setImplementation(original_snapshotParametersMethod, swizzledSnapshotParametersImp);

  Method original_requestSnapshotForElementMethod = class_getInstanceMethod(self.class, @selector(requestSnapshotForElement:attributes:parameters:error:));
  IMP swizzledRequestSnapshotForElementImp = (IMP)swizzledRequestSnapshotForElement;
  original_requestSnapshotForElement = (id (*)(id, SEL, id, id, id, NSError **)) method_setImplementation(original_requestSnapshotForElementMethod, swizzledRequestSnapshotForElementImp);
}

#pragma clang diagnostic pop

@end
