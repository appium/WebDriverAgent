/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
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

- (XCUIElement *)fb_stableInstanceWithUid:(NSString *)uid
{
  if (nil == uid || ![self.fb_isResolvedNatively boolValue] || [self isKindOfClass:XCUIApplication.class]) {
    return self;
  }
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", FBStringify(FBXCElementSnapshotWrapper, fb_uid), uid];
  @autoreleasepool {
    XCUIElementQuery *query = [self.application.fb_query descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *result = [query matchingPredicate:predicate].allElementsBoundByIndex.firstObject;
    if (nil != result) {
      result.fb_isResolvedNatively = @NO;
      return result;
    }
  }
  return self;
}

@end
