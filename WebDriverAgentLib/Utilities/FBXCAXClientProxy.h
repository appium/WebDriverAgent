/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

@protocol FBXCAccessibilityElement;

NS_ASSUME_NONNULL_BEGIN

/**
 This class acts as a proxy between WDA and XCAXClient_iOS.
 Other classes are obliged to use its methods instead of directly accessing XCAXClient_iOS,
 since Apple resticted the interface of XCAXClient_iOS class since Xcode10.2
 */
@interface FBXCAXClientProxy : NSObject

+ (instancetype)sharedClient;

- (BOOL)setAXTimeout:(NSTimeInterval)timeout error:(NSError **)error;

- (nullable id<FBXCElementSnapshot>)snapshotForElement:(id<FBXCAccessibilityElement>)element
                                            attributes:(nullable NSArray<NSString *> *)attributes
                                               inDepth:(BOOL)inDepth
                                                 error:(NSError **)error;

- (NSArray<id<FBXCAccessibilityElement>> *)activeApplications;

- (id<FBXCAccessibilityElement>)systemApplication;

- (NSDictionary *)defaultParameters;

- (void)notifyWhenNoAnimationsAreActiveForApplication:(XCUIApplication *)application
                                                reply:(void (^)(void))reply;

- (nullable NSDictionary *)attributesForElement:(id<FBXCAccessibilityElement>)element
                                     attributes:(NSArray *)attributes
                                          error:(NSError**)error;

- (nullable XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)pid;

@end

NS_ASSUME_NONNULL_END
