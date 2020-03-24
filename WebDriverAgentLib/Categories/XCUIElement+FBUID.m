/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBUID.h"

#import "XCUIElement+FBUtilities.h"
#import "FBElementUtils.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElementQuery.h"

@implementation XCUIElement (FBUID)

- (NSString *)fb_uid
{
  if ([self respondsToSelector:@selector(accessibilityElement)]) {
    return [FBElementUtils uidWithAccessibilityElement:[self performSelector:@selector(accessibilityElement)]];
  }
  static dispatch_once_t onceToken;
  static BOOL useUniqueMatchingSnapshot;
  dispatch_once(&onceToken, ^{
    useUniqueMatchingSnapshot = [self.query respondsToSelector:@selector(uniqueMatchingSnapshotWithError:)];
  });
  if (!useUniqueMatchingSnapshot) {
    return self.fb_lastSnapshot.fb_uid;
  }
  NSError *error = nil;
  // Using the Xcode 11 snapshot function used for resolving an element to validate existance and retrieve UID with the same snapshot
  // Removes the need to take two snapshots (one for existance and one for resolving)
  XCElementSnapshot *snapshot = [[self query] uniqueMatchingSnapshotWithError:&error];
  if (snapshot == nil) {
    [FBLogger logFmt:@"Error retrieving snapshot for UID calculation: [%@]", error];
    return nil;
  }
  return snapshot.fb_uid;
}

@end

@implementation XCElementSnapshot (FBUID)

- (NSString *)fb_uid
{
  return [FBElementUtils uidWithAccessibilityElement:self.accessibilityElement];
}

@end
