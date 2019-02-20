/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import "XCElementSnapshot.h"
#import "XCAccessibilityElement.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBXCAXClientProxy : NSObject

+ (instancetype)sharedClient;

- (NSArray<XCAccessibilityElement *> *)activeApplications;

- (XCAccessibilityElement *)systemApplication;

- (NSDictionary *)defaultParameters;

- (void)notifyWhenNoAnimationsAreActiveForApplication:(id)arg1 reply:(void (^)(void))arg2;

- (NSDictionary *)attributesForElementSnapshot:(XCElementSnapshot *)arg1 attributeList:(NSArray *)arg2;

- (BOOL)providesProcessIdentifier;

- (XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)arg1;

@end

NS_ASSUME_NONNULL_END
