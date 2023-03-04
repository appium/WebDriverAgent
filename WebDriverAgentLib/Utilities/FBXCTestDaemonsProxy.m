/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestDaemonsProxy.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBRunLoopSpinner.h"
#import "XCTestDriver.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIApplication.h"
#import "XCUIDevice.h"

@implementation FBXCTestDaemonsProxy

static Class FBXCTRunnerDaemonSessionClass = nil;
static dispatch_once_t onceTestRunnerDaemonClass;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"

+ (void)load
{
  // XCTRunnerDaemonSession class is only available since Xcode 8.3
  dispatch_once(&onceTestRunnerDaemonClass, ^{
    FBXCTRunnerDaemonSessionClass = objc_lookUpClass("XCTRunnerDaemonSession");
  });
}

#pragma clang diagnostic pop

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy
{
  static id<XCTestManager_ManagerInterface> proxy = nil;
  if ([FBConfiguration shouldUseSingletonTestManager]) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [FBLogger logFmt:@"Using singleton test manager"];
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
  return ((XCTRunnerDaemonSession *)[FBXCTRunnerDaemonSessionClass sharedSession]).daemonProxy;
}

#if !TARGET_OS_TV
+ (UIInterfaceOrientation)orientationWithApplication:(XCUIApplication *)application
{
  if (nil == FBXCTRunnerDaemonSessionClass ||
      [[FBXCTRunnerDaemonSessionClass sharedSession] useLegacyEventCoordinateTransformationPath]) {
    return application.interfaceOrientation;
  }
  return UIInterfaceOrientationPortrait;
}
#endif

+ (BOOL)synthesizeEventWithRecord:(XCSynthesizedEventRecord *)record error:(NSError *__autoreleasing*)error
{
  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    void (^errorHandler)(NSError *) = ^(NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      didSucceed = (invokeError == nil);
      completion();
    };
    
    if (nil == FBXCTRunnerDaemonSessionClass) {
      [[self testRunnerProxy] _XCT_synthesizeEvent:record completion:errorHandler];
    } else {
      XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *innerRecord, NSError *invokeError) {
        errorHandler(invokeError);
      };
      [[XCUIDevice.sharedDevice eventSynthesizer] synthesizeEvent:record completion:(id)^(BOOL result, NSError *invokeError) {
        handlerBlock(record, invokeError);
      }];
    }
  }];
  return didSucceed;
}

+ (BOOL)openURL:(NSURL *)url usingApplication:(NSString *)bundleId error:(NSError *__autoreleasing*)error
{
  XCTRunnerDaemonSession *session = [FBXCTRunnerDaemonSessionClass sharedSession];
  if (![session respondsToSelector:@selector(openURL:usingApplication:completion:)]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The current Xcode SDK does not support opening of URLs with given application"]
       buildError:error];
    }
    return NO;
  }

  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [session openURL:url usingApplication:bundleId completion:^(bool result, NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      didSucceed = invokeError == nil && result;
      completion();
    }];
  }];
  return didSucceed;
}

+ (BOOL)openDefaultApplicationForURL:(NSURL *)url error:(NSError *__autoreleasing*)error
{
  XCTRunnerDaemonSession *session = [FBXCTRunnerDaemonSessionClass sharedSession];
  if (![session respondsToSelector:@selector(openDefaultApplicationForURL:completion:)]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The current Xcode SDK does not support opening of URLs. Consider upgrading to Xcode 14.3+/iOS 16.4+"]
       buildError:error];
    }
    return NO;
  }

  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [session openDefaultApplicationForURL:url completion:^(bool result, NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      didSucceed = invokeError == nil && result;
      completion();
    }];
  }];
  return didSucceed;
}

#if !TARGET_OS_TV
+ (BOOL)setSimulatedLocation:(CLLocation *)location error:(NSError *__autoreleasing*)error
{
  XCTRunnerDaemonSession *session = [FBXCTRunnerDaemonSessionClass sharedSession];
  if (![session respondsToSelector:@selector(setSimulatedLocation:completion:)]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The current Xcode SDK does not support location simulation. Consider upgrading to Xcode 14.3+/iOS 16.4+"]
       buildError:error];
    }
    return NO;
  }
  if (![session supportsLocationSimulation]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Your device does not support location simulation"]
       buildError:error];
    }
    return NO;
  }

  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [session setSimulatedLocation:location completion:^(bool result, NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      didSucceed = invokeError == nil && result;
      completion();
    }];
  }];
  return didSucceed;
}

+ (nullable CLLocation *)getSimulatedLocation:(NSError *__autoreleasing*)error;
{
  XCTRunnerDaemonSession *session = [FBXCTRunnerDaemonSessionClass sharedSession];
  if (![session respondsToSelector:@selector(getSimulatedLocationWithReply:)]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The current Xcode SDK does not support location simulation. Consider upgrading to Xcode 14.3+/iOS 16.4+"]
       buildError:error];
    }
    return nil;
  }
  if (![session supportsLocationSimulation]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Your device does not support location simulation"]
       buildError:error];
    }
    return nil;
  }

  __block CLLocation *location = nil;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [session getSimulatedLocationWithReply:^(CLLocation *reply, NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      if (nil == invokeError) {
        location = reply;
      }
      completion();
    }];
  }];
  return location;
}

+ (BOOL)clearSimulatedLocation:(NSError *__autoreleasing*)error
{
  XCTRunnerDaemonSession *session = [FBXCTRunnerDaemonSessionClass sharedSession];
  if (![session respondsToSelector:@selector(clearSimulatedLocationWithReply:)]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"The current Xcode SDK does not support location simulation. Consider upgrading to Xcode 14.3+/iOS 16.4+"]
       buildError:error];
    }
    return NO;
  }
  if (![session supportsLocationSimulation]) {
    if (error) {
      [[[FBErrorBuilder builder]
        withDescriptionFormat:@"Your device does not support location simulation"]
       buildError:error];
    }
    return NO;
  }

  __block BOOL didSucceed = NO;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    [session clearSimulatedLocationWithReply:^(bool result, NSError *invokeError) {
      if (error) {
        *error = invokeError;
      }
      didSucceed = invokeError == nil && result;
      completion();
    }];
  }];
  return didSucceed;
}
#endif

@end
