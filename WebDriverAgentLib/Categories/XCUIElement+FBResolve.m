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
  XCElementSnapshot *cachedSnapshot = self.fb_cachedSnapshot;
  NSString *uid = nil == cachedSnapshot ? self.fb_uid : cachedSnapshot.fb_uid;
  return nil == uid
    ? self
    : [query matchingPredicate:[NSPredicate predicateWithFormat:@"%K = %@", FBStringify(XCUIElement, wdUID), uid]].fb_firstMatch;
}

@end
