/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBLogger.h"
#import "XCUIElement+FBMinMax.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestPrivateSymbols.h"

@interface FBXCElementSnapshotWrapper (FBMinMaxInternal)

- (NSNumber *)fb_numericAttribute:(NSString *)attributeName symbol:(NSNumber *)symbol;

@end

@implementation XCUIElement (FBMinMax)

- (NSNumber *)fb_minValue
{
  @autoreleasepool {
    id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
    return [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_minValue];
  }
}

- (NSNumber *)fb_maxValue
{
  @autoreleasepool {
    id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
    return [[FBXCElementSnapshotWrapper ensureWrapped:snapshot] fb_maxValue];
  }
}

@end

@implementation FBXCElementSnapshotWrapper (FBMinMax)

- (NSNumber *)fb_minValue
{
  return [self fb_numericAttribute:FB_XCAXACustomMinValueAttributeName
                            symbol:FB_XCAXACustomMinValueAttribute];
}

- (NSNumber *)fb_maxValue
{
  return [self fb_numericAttribute:FB_XCAXACustomMaxValueAttributeName
                            symbol:FB_XCAXACustomMaxValueAttribute];
}

- (NSNumber *)fb_numericAttribute:(NSString *)attributeName symbol:(NSNumber *)symbol
{
  NSNumber *cached = (self.snapshot.additionalAttributes ?: @{})[symbol];
  if (cached) {
    return cached;
  }

  NSError *error = nil;
  NSNumber *raw = [self fb_attributeValue:attributeName error:&error];
  if (raw) {
    NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:self.additionalAttributes ?: @{}];
    updated[symbol] = raw;
    self.snapshot.additionalAttributes = updated.copy;
    return raw;
  }

  [FBLogger logFmt:@"[FBMinMax] Cannot determine %@ for %@: %@", attributeName, self.fb_description, error.localizedDescription];
  return nil;
}

@end
