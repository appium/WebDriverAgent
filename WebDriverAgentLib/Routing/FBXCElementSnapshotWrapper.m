/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCElementSnapshotWrapper.h"

#import "FBElementUtils.h"

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
  static dispatch_once_t onceToken;
  static NSSet<NSString *> *allNames;
  dispatch_once(&onceToken, ^{
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    [names unionSet:[FBElementUtils selectorNamesWithProtocol:@protocol(FBXCElementSnapshot)]];
    [names unionSet:[FBElementUtils selectorNamesWithProtocol:@protocol(XCUIElementAttributes)]];
    allNames = [names copy];
  });
  return [allNames containsObject:NSStringFromSelector(aSelector)] ? self.snapshot : nil;
}

@end

#pragma clang diagnostic pop
