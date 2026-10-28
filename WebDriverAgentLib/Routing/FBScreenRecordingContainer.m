/**
 *
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScreenRecordingContainer.h"

#import "FBLogger.h"
#import "FBScreenRecordingPromise.h"

@interface FBScreenRecordingContainer ()

@property (readwrite) NSUInteger fps;
@property (readwrite) long long codec;
@property (readwrite, nullable) FBScreenRecordingPromise* screenRecordingPromise;
@property (readwrite, nullable) NSNumber *startedAt;

- (void)performAttachmentCleanupForPromise:(FBScreenRecordingPromise *)promise;

@end

@implementation FBScreenRecordingContainer

+ (instancetype)sharedInstance
{
  static FBScreenRecordingContainer *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (void)storeScreenRecordingPromise:(FBScreenRecordingPromise *)screenRecordingPromise
                                fps:(NSUInteger)fps
                              codec:(long long)codec;
{
  @synchronized (self) {
    self.fps = fps;
    self.codec = codec;
    self.screenRecordingPromise = screenRecordingPromise;
    self.startedAt = @([NSDate.date timeIntervalSince1970]);
  }
}

- (nullable FBScreenRecordingPromise *)detachScreenRecordingPromiseMatching:(nullable FBScreenRecordingPromise *)expectedPromise
                                                                   matchAny:(BOOL)matchAny
{
  @synchronized (self) {
    if (nil == self.screenRecordingPromise || (!matchAny && self.screenRecordingPromise != expectedPromise)) {
      return nil;
    }
    FBScreenRecordingPromise *detachedPromise = self.screenRecordingPromise;
    self.fps = 0;
    self.codec = 0;
    self.screenRecordingPromise = nil;
    self.startedAt = nil;
    return detachedPromise;
  }
}

- (void)performAttachmentCleanupForPromise:(FBScreenRecordingPromise *)promise
{
  [XCTContext runActivityNamed:@"Video Cleanup" block:^(id<XCTActivity> activity){
    [activity addAttachment:(XCTAttachment *)promise.nativePromise];
  }];
}

- (void)cleanUpScreenRecordingPromise:(nullable FBScreenRecordingPromise *)promise
{
  if (nil == promise || nil == promise.nativePromise) {
    return;
  }
  @try {
    [self performAttachmentCleanupForPromise:promise];
  } @catch (NSException *exception) {
    [FBLogger logFmt:@"Failed to clean up screen recording attachment: %@", exception.reason];
  }
}

- (void)reset;
{
  FBScreenRecordingPromise *detachedPromise = [self detachScreenRecordingPromiseMatching:nil matchAny:YES];
  [self cleanUpScreenRecordingPromise:detachedPromise];
}

- (BOOL)resetIfPromiseIs:(FBScreenRecordingPromise *)screenRecordingPromise
{
  FBScreenRecordingPromise *detachedPromise = [self detachScreenRecordingPromiseMatching:screenRecordingPromise
                                                                                matchAny:NO];
  if (nil == detachedPromise) {
    return NO;
  }
  [self cleanUpScreenRecordingPromise:detachedPromise];
  return YES;
}

- (nullable NSDictionary *)toDictionary
{
  @synchronized (self) {
    if (nil == self.screenRecordingPromise) {
      return nil;
    }

    return @{
      @"fps": @(self.fps),
      @"codec": @(self.codec),
      @"uuid": [self.screenRecordingPromise identifier].UUIDString ?: [NSNull null],
      @"startedAt": self.startedAt ?: [NSNull null],
    };
  }
}

@end
