/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCAXClientProxy.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBLogger.h"
#import "XCAXClient_iOS.h"
#import "XCUIDevice.h"

static id FBAXClient = nil;

@implementation XCAXClient_iOS (WebDriverAgent)

/**
 Parameters for traversing elements tree from parents to children while requesting XCElementSnapshot.

 @return dictionary with parameters for element's snapshot request
 */
- (NSDictionary *)fb_getParametersForElementSnapshot
{
  return FBConfiguration.snapshotRequestParameters;
}

+ (void)load
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      Class class = [self class];

      SEL originalSelector = @selector(defaultParameters);
      SEL swizzledSelector = @selector(fb_getParametersForElementSnapshot);

      Method originalMethod = class_getInstanceMethod(class, originalSelector);
      Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

      BOOL didAddMethod =
          class_addMethod(class,
              originalSelector,
              method_getImplementation(swizzledMethod),
              method_getTypeEncoding(swizzledMethod));

      if (didAddMethod) {
          class_replaceMethod(class,
              swizzledSelector,
              method_getImplementation(originalMethod),
              method_getTypeEncoding(originalMethod));
      } else {
          method_exchangeImplementations(originalMethod, swizzledMethod);
      }
  });
}

@end

@implementation FBXCAXClientProxy

+ (instancetype)sharedClient
{
  static FBXCAXClientProxy *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
    if ([XCAXClient_iOS.class respondsToSelector:@selector(sharedClient)]) {
      FBAXClient = [XCAXClient_iOS sharedClient];
    } else {
      FBAXClient = [XCUIDevice.sharedDevice accessibilityInterface];
    }
  });
  return instance;
}

- (BOOL)setAXTimeout:(NSTimeInterval)timeout error:(NSError **)error
{
  return [FBAXClient _setAXTimeout:timeout error:error];
}

- (XCElementSnapshot *)snapshotForElement:(XCAccessibilityElement *)element
                               attributes:(NSArray<NSString *> *)attributes
                                 maxDepth:(nullable NSNumber *)maxDepth
                                    error:(NSError **)error
{
  NSMutableDictionary *parameters = nil;
  if (nil != maxDepth) {
    parameters = self.defaultParameters.mutableCopy;
    parameters[FBSnapshotMaxDepthKey] = maxDepth;
  }
  if ([FBAXClient respondsToSelector:@selector(requestSnapshotForElement:attributes:parameters:error:)]) {
    id result = [FBAXClient requestSnapshotForElement:element
                                           attributes:attributes
                                           parameters:[parameters copy]
                                                error:error];
    XCElementSnapshot *snapshot = [result valueForKey:@"_rootElementSnapshot"];
    return nil == snapshot ? result : snapshot;
  }
  return [FBAXClient snapshotForElement:element
                             attributes:attributes
                             parameters:[parameters copy]
                                  error:error];
}

- (NSArray<XCAccessibilityElement *> *)activeApplications
{
  return [FBAXClient activeApplications];
}

- (XCAccessibilityElement *)systemApplication
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

- (NSDictionary *)attributesForElement:(XCAccessibilityElement *)element
                            attributes:(NSArray *)attributes
{
  if ([FBAXClient respondsToSelector:@selector(attributesForElement:attributes:error:)]) {
    NSError *error = nil;
    NSDictionary* result = [FBAXClient attributesForElement:element
                                                 attributes:attributes
                                                      error:&error];
    if (error) {
      [FBLogger logFmt:@"Cannot retrieve element attribute(s) %@. Original error: %@", attributes, error.description];
    }
    return result;
  }
  return [FBAXClient attributesForElement:element attributes:attributes];
}

- (BOOL)hasProcessTracker
{
  static BOOL hasTracker;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    hasTracker = [FBAXClient respondsToSelector:@selector(applicationProcessTracker)];
  });
  return hasTracker;
}

- (XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)pid
{
  return [[FBAXClient applicationProcessTracker] monitoredApplicationWithProcessIdentifier:pid];
}

@end
