/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#if !TARGET_OS_TV
#import <CoreLocation/CoreLocation.h>
#endif

#import "XCSynthesizedEventRecord.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XCTestManager_ManagerInterface;
@class FBScreenRecordingRequest, FBScreenRecordingPromise;

@interface FBXCTestDaemonsProxy : NSObject

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy;

+ (BOOL)synthesizeEventWithRecord:(XCSynthesizedEventRecord *)record
                            error:(NSError *__autoreleasing*)error;

+ (BOOL)openURL:(NSURL *)url usingApplication:(NSString *)bundleId error:(NSError **)error;
+ (BOOL)openDefaultApplicationForURL:(NSURL *)url error:(NSError **)error;

+ (nullable FBScreenRecordingPromise *)startScreenRecordingWithRequest:(FBScreenRecordingRequest *)request
                                                                 error:(NSError **)error;
+ (BOOL)stopScreenRecordingWithUUID:(NSUUID *)uuid
                              error:(NSError **)error;

#if !TARGET_OS_TV
+ (BOOL)setSimulatedLocation:(CLLocation *)location error:(NSError **)error;
+ (nullable CLLocation *)getSimulatedLocation:(NSError **)error;
+ (BOOL)clearSimulatedLocation:(NSError **)error;
#endif

@end

NS_ASSUME_NONNULL_END
