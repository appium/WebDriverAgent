/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBResolve.h"

#import <objc/runtime.h>

#import "XCUIElement.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement+FBUID.h"

@implementation XCUIElement (FBResolve)

static char XCUIELEMENT_IS_RESOLVED_NATIVELY_KEY;

@dynamic fb_isResolvedNatively;

- (void)setFb_isResolvedNatively:(NSNumber *)isResolvedNatively
{
  objc_setAssociatedObject(self, &XCUIELEMENT_IS_RESOLVED_NATIVELY_KEY, isResolvedNatively, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)fb_isResolvedNatively
{
  NSNumber *result = objc_getAssociatedObject(self, &XCUIELEMENT_IS_RESOLVED_NATIVELY_KEY);
  return nil == result ? @YES : result;
}

- (XCUIElement *)fb_stableInstance
{
  if (![self.fb_isResolvedNatively boolValue]) {
    return self;
  }

  XCUIElementQuery *query = [self isKindOfClass:XCUIApplication.class]
    ? self.application.fb_query
    : [self.application.fb_query descendantsMatchingType:XCUIElementTypeAny];
  NSString *uid = nil == self.fb_cachedSnapshot
    ? self.fb_uid
    : [FBXCElementSnapshotWrapper wdUIDWithSnapshot:(id)self.fb_cachedSnapshot];
  if (nil == uid) {
    return self;
  }
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@",FBStringify(FBXCElementSnapshotWrapper, fb_uid), uid];
  return [query matchingPredicate:predicate].allElementsBoundByIndex.firstObject ?: self;
}

@end
