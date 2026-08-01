/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCAccessibilityElementDouble.h"

@implementation FBXCAccessibilityElementDouble

- (instancetype)initWithElementId:(unsigned long long)elementId
{
  self = [super init];
  if (self) {
    _payload = @{@"uid.elementID": @(elementId)};
    // Must stay in sync with FBXCElementSnapshotDoubleProcessIdentifier in
    // FBXCElementSnapshotDouble.m, which independently derives the same uid.
    _processIdentifier = 1;
  }
  return self;
}

@end
