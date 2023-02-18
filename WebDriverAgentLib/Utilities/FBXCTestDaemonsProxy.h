/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import "XCSynthesizedEventRecord.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XCTestManager_ManagerInterface;

@interface FBXCTestDaemonsProxy : NSObject

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy;

#if !TARGET_OS_TV
+ (UIInterfaceOrientation)orientationWithApplication:(XCUIApplication *)application;
#endif

+ (BOOL)synthesizeEventWithRecord:(XCSynthesizedEventRecord *)record
                            error:(NSError *__autoreleasing*)error;

+ (BOOL)openURL:(NSURL *)url usingApplication:(NSString *)bundleId error:(NSError **)error;
+ (BOOL)openDefaultApplicationForURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
