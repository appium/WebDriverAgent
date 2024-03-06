/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBVideoCommands.h"

#import "FBRouteRequest.h"
#import "FBScreenRecordingContainer.h"
#import "FBScreenRecordingPromise.h"
#import "FBScreenRecordingRequest.h"
#import "FBSession.h"
#import "FBXCTestDaemonsProxy.h"

const NSUInteger DEFAULT_FPS = 24;
const NSUInteger DEFAULT_CODEC = 0;

@implementation FBVideoCommands

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/wda/video/start"] respondWithTarget:self action:@selector(handleStartVideoRecording:)],
    [[FBRoute POST:@"/wda/video/stop"] respondWithTarget:self action:@selector(handleStopVideoRecording:)],
    [[FBRoute GET:@"/wda/video"] respondWithTarget:self action:@selector(handleGetVideoRecording:)],

    [[FBRoute POST:@"/wda/video/start"].withoutSession respondWithTarget:self action:@selector(handleStartVideoRecording:)],
    [[FBRoute POST:@"/wda/video/stop"].withoutSession respondWithTarget:self action:@selector(handleStopVideoRecording:)],
    [[FBRoute GET:@"/wda/video"].withoutSession respondWithTarget:self action:@selector(handleGetVideoRecording:)],
  ];
}

+ (id<FBResponsePayload>)handleStartVideoRecording:(FBRouteRequest *)request
{
  FBScreenRecordingPromise *activeScreenRecording = FBScreenRecordingContainer.sharedInstance.screenRecordingPromise;
  if (nil != activeScreenRecording) {
    return FBResponseWithObject([FBScreenRecordingContainer.sharedInstance toDictionary] ?: [NSNull null]);
  }

  NSNumber *fps = (NSNumber *)request.arguments[@"fps"] ?: @(DEFAULT_FPS);
  NSNumber *codec = (NSNumber *)request.arguments[@"codec"] ?: @(DEFAULT_CODEC);
  FBScreenRecordingRequest *recordingRequest = [[FBScreenRecordingRequest alloc] initWithFps:fps.integerValue
                                                                                       codec:codec.longLongValue];
  NSError *error;
  FBScreenRecordingPromise* promise = [FBXCTestDaemonsProxy startScreenRecordingWithRequest:recordingRequest
                                                                                      error:&error];
  if (nil == promise) {
    [FBScreenRecordingContainer.sharedInstance reset];
    return FBResponseWithUnknownError(error);
  }
  [FBScreenRecordingContainer.sharedInstance storeScreenRecordingPromise:promise
                                                                     fps:fps.integerValue
                                                                   codec:codec.longLongValue];
  return FBResponseWithObject([FBScreenRecordingContainer.sharedInstance toDictionary]);
}

+ (id<FBResponsePayload>)handleStopVideoRecording:(FBRouteRequest *)request
{
  FBScreenRecordingPromise *activeScreenRecording = FBScreenRecordingContainer.sharedInstance.screenRecordingPromise;
  if (nil == activeScreenRecording) {
    return FBResponseWithOK();
  }

  NSUUID *recordingId = activeScreenRecording.identifier;
  NSDictionary *response = [FBScreenRecordingContainer.sharedInstance toDictionary];
  NSError *error;
  if (![FBXCTestDaemonsProxy stopScreenRecordingWithUUID:recordingId error:&error]) {
    [FBScreenRecordingContainer.sharedInstance reset];
    return FBResponseWithUnknownError(error);
  }
  [FBScreenRecordingContainer.sharedInstance reset];
  return FBResponseWithObject(response);
}

+ (id<FBResponsePayload>)handleGetVideoRecording:(FBRouteRequest *)request
{
  return FBResponseWithObject([FBScreenRecordingContainer.sharedInstance toDictionary] ?: [NSNull null]);
}

@end
