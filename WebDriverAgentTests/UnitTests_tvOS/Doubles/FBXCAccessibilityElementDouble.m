/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCAccessibilityElementDouble.h"

const int FBXCAccessibilityElementDoubleProcessIdentifier = 1;

@implementation FBXCAccessibilityElementDouble

- (instancetype)initWithElementId:(unsigned long long)elementId
{
  self = [super init];
  if (self) {
    _payload = @{@"uid.elementID": @(elementId)};
    _processIdentifier = FBXCAccessibilityElementDoubleProcessIdentifier;
  }
  return self;
}

@end
