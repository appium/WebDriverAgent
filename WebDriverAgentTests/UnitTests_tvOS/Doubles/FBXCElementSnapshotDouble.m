/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXCElementSnapshotDouble.h"

// FBElementUtils.h (which defines the real uid formula) is a private
// WebDriverAgentLib header not visible to the test target, so
// +wdUIDForElementId: below duplicates the same elementId+processId -> NSUUID
// derivation (see FBElementUtils.m) rather than importing it. It reuses
// FBXCAccessibilityElementDoubleProcessIdentifier so the two stay in sync.
@implementation FBXCElementSnapshotDouble

+ (instancetype)snapshotWithElementId:(unsigned long long)elementId
                                 frame:(CGRect)frame
                              hasFocus:(BOOL)hasFocus
{
  FBXCElementSnapshotDouble *snapshot = [self new];
  snapshot.accessibilityElement = [[FBXCAccessibilityElementDouble alloc] initWithElementId:elementId];
  snapshot.frame = frame;
  snapshot.hasFocus = hasFocus;
  snapshot.children = @[];
  return snapshot;
}

+ (NSString *)wdUIDForElementId:(unsigned long long)elementId
{
  int processId = FBXCAccessibilityElementDoubleProcessIdentifier;
  uint8_t bytes[16] = {0};
  memcpy(bytes, &elementId, sizeof(elementId));
  memcpy(bytes + sizeof(elementId), &processId, sizeof(processId));
  return [[[NSUUID alloc] initWithUUIDBytes:bytes] UUIDString];
}

- (void)enumerateDescendantsUsingBlock:(void (^)(id snapshot))block
{
  for (FBXCElementSnapshotDouble *child in self.children) {
    block(child);
    [child enumerateDescendantsUsingBlock:block];
  }
}

@end
