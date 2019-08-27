/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplication.h"

#import "FBApplicationProcessProxy.h"
#import "FBLogger.h"
#import "FBRunLoopSpinner.h"
#import "FBMacros.h"
#import "FBXCodeCompatibility.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCAccessibilityElement.h"
#import "XCUIApplication.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"
#import "FBXCAXClientProxy.h"
#import "XCUIApplicationProcessQuiescence.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestPrivateSymbols.h"
#import "XCTRunnerDaemonSession.h"

static const NSTimeInterval APP_STATE_STABILITY_WINDOW = 1.0;
static const NSTimeInterval APP_STATE_STABILITY_TIMEOUT = 5.0;

@interface FBApplication ()
@property (nonatomic, assign) BOOL fb_isObservingAppImplCurrentProcess;
@end

@implementation FBApplication

+ (nullable XCAccessibilityElement *)fb_currentAppElement
{
  CGPoint screenPoint = CGPointMake(100, 100);
  __block XCAccessibilityElement *onScreenElement = nil;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestElementAtPoint:screenPoint
                              reply:^(XCAccessibilityElement *element, NSError *error) {
                                if (nil == error) {
                                  onScreenElement = element;
                                }
                                dispatch_semaphore_signal(sem);
                              }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)));
  return onScreenElement;
}

+ (instancetype)fb_activeApplication
{
  __block XCAccessibilityElement *currentAppElement = nil;
  __block XCAccessibilityElement *previousAppElement = self.fb_currentAppElement;
  if (![[[FBRunLoopSpinner new]
    timeout:APP_STATE_STABILITY_TIMEOUT]
   spinUntilTrue:^BOOL{
     if ([[[FBRunLoopSpinner new]
           timeout:APP_STATE_STABILITY_WINDOW]
          spinUntilTrue:^BOOL{
            currentAppElement = self.fb_currentAppElement;
            return !currentAppElement
              || !previousAppElement
              || currentAppElement.processIdentifier != previousAppElement.processIdentifier;
          }]) {
       previousAppElement = currentAppElement;
       return NO;
     }
     return YES;
   }]) {
     [FBLogger logFmt:@"Application state has not been stabilized within %.2f seconds timeout", APP_STATE_STABILITY_TIMEOUT];
  }

  NSArray<XCAccessibilityElement *> *activeApplicationElements = [FBXCAXClientProxy.sharedClient activeApplications];
  XCAccessibilityElement *activeApplicationElement = [activeApplicationElements lastObject];
  if (nil != currentAppElement && activeApplicationElements.count > 1) {
    for (XCAccessibilityElement *appElement in activeApplicationElements) {
      if (appElement.processIdentifier == currentAppElement.processIdentifier) {
        activeApplicationElement = appElement;
        break;
      }
    }
  }
  if (nil == activeApplicationElement) {
    return nil;
  }
  FBApplication *application = [FBApplication fb_applicationWithPID:activeApplicationElement.processIdentifier];
  NSAssert(nil != application, @"Active application instance is not expected to be equal to nil", nil);
  return application;
}

+ (instancetype)fb_systemApplication
{
  return [self fb_applicationWithPID:
   [[FBXCAXClientProxy.sharedClient systemApplication] processIdentifier]];
}

+ (instancetype)appWithPID:(pid_t)processID
{
  if ([NSProcessInfo processInfo].processIdentifier == processID) {
    return nil;
  }
  FBApplication *application = [self fb_registeredApplicationWithProcessID:processID];
  if (application) {
    return application;
  }
  application = [super appWithPID:processID];
  [FBApplication fb_registerApplication:application withProcessID:processID];
  return application;
}

+ (instancetype)applicationWithPID:(pid_t)processID
{
  if ([NSProcessInfo processInfo].processIdentifier == processID) {
    return nil;
  }
  FBApplication *application = [self fb_registeredApplicationWithProcessID:processID];
  if (application) {
    return application;
  }
  if ([FBXCAXClientProxy.sharedClient hasProcessTracker]) {
    application = (FBApplication *)[FBXCAXClientProxy.sharedClient monitoredApplicationWithProcessIdentifier:processID];
  } else {
    application = [super applicationWithPID:processID];
  }
  [FBApplication fb_registerApplication:application withProcessID:processID];
  return application;
}

- (void)launch
{
  [XCUIApplicationProcessQuiescence setQuiescenceCheck:self.fb_shouldWaitForQuiescence];
  [super launch];
  [FBApplication fb_registerApplication:self withProcessID:self.processID];
}

- (void)terminate
{
  if (self.fb_isObservingAppImplCurrentProcess) {
    [self.fb_appImpl removeObserver:self forKeyPath:FBStringify(XCUIApplicationImpl, currentProcess)];
  }
  [super terminate];
}


#pragma mark - Quiescence

- (void)_waitForQuiescence
{
  if (!self.fb_shouldWaitForQuiescence) {
    return;
  }
  [super _waitForQuiescence];
}

- (XCUIApplicationImpl *)fb_appImpl
{
  if (![self respondsToSelector:@selector(applicationImpl)]) {
    return nil;
  }
  XCUIApplicationImpl *appImpl = [self applicationImpl];
  if (![appImpl respondsToSelector:@selector(currentProcess)]) {
    return nil;
  }
  return appImpl;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context
{
  if (![keyPath isEqualToString:FBStringify(XCUIApplicationImpl, currentProcess)]) {
    return;
  }
  if ([change[NSKeyValueChangeKindKey] unsignedIntegerValue] != NSKeyValueChangeSetting) {
    return;
  }
  XCUIApplicationProcess *applicationProcess = change[NSKeyValueChangeNewKey];
  if (!applicationProcess || [applicationProcess isProxy] || ![applicationProcess isMemberOfClass:XCUIApplicationProcess.class]) {
    return;
  }
  [object setValue:[FBApplicationProcessProxy proxyWithApplicationProcess:applicationProcess] forKey:keyPath];
}


#pragma mark - Process registration

static NSMutableDictionary *FBPidToApplicationMapping;

+ (instancetype)fb_registeredApplicationWithProcessID:(pid_t)processID
{
  return FBPidToApplicationMapping[@(processID)];
}

+ (void)fb_registerApplication:(XCUIApplication *)application withProcessID:(pid_t)processID
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FBPidToApplicationMapping = [NSMutableDictionary dictionary];
  });
  FBPidToApplicationMapping[@(application.processID)] = application;
}

@end
