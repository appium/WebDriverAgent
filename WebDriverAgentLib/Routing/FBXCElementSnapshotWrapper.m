/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCElementSnapshotWrapper.h"

#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wprotocol"

@implementation FBXCElementSnapshotWrapper

- (instancetype)initWithSnapshot:(id<FBXCElementSnapshot>)snapshot;
{
  self->_snapshot = snapshot;
  return self;
}

+ (instancetype)ensureWrapped:(id<FBXCElementSnapshot>)snapshot
{
  if (nil == snapshot) {
    return nil;
  }
  return [(NSObject *)snapshot isKindOfClass:self.class]
    ? (FBXCElementSnapshotWrapper *)snapshot
    : [[FBXCElementSnapshotWrapper alloc] initWithSnapshot:snapshot];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  struct objc_method_description descr = protocol_getMethodDescription(@protocol(FBXCElementSnapshot), aSelector, YES, YES);
  SEL selector = descr.name;
  return nil == selector ? nil : self.snapshot;
}

@end

#pragma clang diagnostic pop
