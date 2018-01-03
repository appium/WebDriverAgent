/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestDaemonsProxy.h"
#import "FBRunLoopSpinner.h"
#import "XCTestDriver.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import <objc/runtime.h>

@implementation FBXCTestDaemonsProxy

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy
{
  static id<XCTestManager_ManagerInterface> proxy = nil;
  if ([FBConfiguration shouldUseSingletonTestManager]) {
    [FBLogger logFmt:@"Using singleton test manager"];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      proxy = [self.class retrieveTestRunnerProxy];
    });
  } else {
    [FBLogger logFmt:@"Using general test manager"];
    proxy = [self.class retrieveTestRunnerProxy];
  }
  NSAssert(proxy != NULL, @"Could not determine testRunnerProxy", proxy);
  return proxy;
}

+ (id<XCTestManager_ManagerInterface>)retrieveTestRunnerProxy
{
  if ([[XCTestDriver sharedTestDriver] respondsToSelector:@selector(managerProxy)]) {
    return [XCTestDriver sharedTestDriver].managerProxy;
  } else {
    Class runnerClass = objc_lookUpClass("XCTRunnerDaemonSession");
    return ((XCTRunnerDaemonSession *)[runnerClass sharedSession]).daemonProxy;
  }
}

+ (UIInterfaceOrientation)orientationWithApplication:(XCUIApplication *)application
{
  Class runnerClass = objc_lookUpClass("XCTRunnerDaemonSession");
  if (nil == runnerClass || [[runnerClass sharedSession] useLegacyEventCoordinateTransformationPath]) {
    return application.interfaceOrientation;
  }
  return UIInterfaceOrientationPortrait;
}

+ (BOOL)synthesizeEventWithRecord:(XCSynthesizedEventRecord *)record error:(NSError *__autoreleasing*)error
{
  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [[self testRunnerProxy] _XCT_synthesizeEvent:record completion:^(NSError *commandError) {
      if (error) {
        *error = commandError;
      }
      didSucceed = (commandError == nil);
      completion();
    }];
  }];
  return didSucceed;
}

+ (XCAccessibilityElement *)accessibilityElementAtPoint:(CGPoint)point error:(NSError *__autoreleasing*)error
{
  __block BOOL didSucceed = NO;
  __block XCAccessibilityElement *resultingAccessiblityElement = nil;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [[self testRunnerProxy] _XCT_requestElementAtPoint:point reply:^(XCAccessibilityElement *commandResult, NSError *commandError) {
      if (error) {
        *error = commandError;
      }
      didSucceed = (commandError == nil);
      if (didSucceed) {
        resultingAccessiblityElement = commandResult;
      }
      completion();
    }];
  }];
  return resultingAccessiblityElement;
}

@end
