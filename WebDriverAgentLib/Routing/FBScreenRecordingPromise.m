/**
 *
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenRecordingPromise.h"

@interface FBScreenRecordingPromise ()
@property (nonatomic) id promise;
@end

@implementation FBScreenRecordingPromise

- (instancetype)initWithNativePromise:(id)promise
{
  if ((self = [super init])) {
    self.promise = promise;
  }
  return self;
}

- (NSUUID *)identifier
{
  return (NSUUID *)[self.promise valueForKey:@"_UUID"];
}

@end
