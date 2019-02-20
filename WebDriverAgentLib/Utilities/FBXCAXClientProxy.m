/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCAXClientProxy.h"
#import "XCAXClient_iOS.h"
#import "XCUIDevice.h"

static id FBAXClient = nil;

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

- (void)notifyWhenNoAnimationsAreActiveForApplication:(id)arg1 reply:(void (^)(void))arg2
{
  [FBAXClient notifyWhenNoAnimationsAreActiveForApplication:arg1 reply:arg2];
}

- (NSDictionary *)attributesForElementSnapshot:(XCElementSnapshot *)arg1 attributeList:(NSArray *)arg2
{
  if ([FBAXClient respondsToSelector:@selector(attributesForElementSnapshot:attributeList:)]) {
    return [FBAXClient attributesForElementSnapshot:arg1 attributeList:arg2];
  }
  return [(id)FBAXClient attributesForElement:[arg1 accessibilityElement]
                                   attributes:arg2
                                        error:nil];
}

- (BOOL)providesProcessIdentifier
{
  return [FBAXClient valueForKey:@"applicationProcessTracker"] != nil;
}

- (XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)arg1
{
  return [[FBAXClient applicationProcessTracker] monitoredApplicationWithProcessIdentifier:arg1];
}

@end
