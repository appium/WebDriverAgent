/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCElementSnapshotDouble.h"

@implementation FBXCElementSnapshotDouble

+ (instancetype)snapshotWithElementId:(unsigned long long)elementId
                                 frame:(CGRect)frame
                              hasFocus:(BOOL)hasFocus
{
  FBXCElementSnapshotDouble *snapshot = [self new];
  snapshot.accessibilityElement = [[FBXCAccessibilityElementDouble alloc] initWithElementId:elementId];
  snapshot.frame = frame;
  snapshot.hasFocus = hasFocus;
  return snapshot;
}

@end
