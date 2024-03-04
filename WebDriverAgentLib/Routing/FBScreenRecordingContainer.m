/**
 *
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenRecordingContainer.h"

#import "FBScreenRecordingPromise.h"

@interface FBScreenRecordingContainer ()

@property (readwrite) NSUInteger fps;
@property (readwrite) long long codec;
@property (readwrite) FBScreenRecordingPromise* screenRecordingPromise;

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

- (void)storeScreenRecordingPromise:(nullable FBScreenRecordingPromise *)screenRecordingPromise
                                fps:(NSUInteger)fps
                              codec:(long long)codec;
{
  self.fps = fps;
  self.codec = codec;
  self.screenRecordingPromise = screenRecordingPromise;
}

- (void)reset;
{
  self.fps = 0;
  self.codec = 0;
  self.screenRecordingPromise = nil;
}

- (nullable NSDictionary *)toDictionary
{
  if (nil == self.screenRecordingPromise) {
    return nil;
  }

  return @{
    @"fps": @(self.fps),
    @"codec": @(self.codec),
    @"uuid": [self.screenRecordingPromise identifier] ?: [NSNull null],
  };
}

@end
