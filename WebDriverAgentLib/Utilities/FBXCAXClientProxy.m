/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCAXClientProxy.h"

#import "FBLogger.h"
#import "XCAXClient_iOS.h"
#import "XCUIDevice.h"
#import <objc/runtime.h>
#import "FBConfiguration.h"

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
      [FBLogger logFmt:@"Cannot retrieve the list of %@ element attributes: %@", attributes, error.description];
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
