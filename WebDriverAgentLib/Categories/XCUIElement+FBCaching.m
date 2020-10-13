/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBCaching.h"

#import <objc/runtime.h>

#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBUtilities.h"

@implementation XCUIElement (FBCaching)

static char XCUIELEMENT_IS_RESOLVED_FROM_CACHE_KEY;

@dynamic fb_isResolvedFromCache;

- (void)setFb_isResolvedFromCache:(NSNumber *)isResolvedFromCache
{
  objc_setAssociatedObject(self, &XCUIELEMENT_IS_RESOLVED_FROM_CACHE_KEY, isResolvedFromCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)fb_isResolvedFromCache
{
  return (NSNumber *)objc_getAssociatedObject(self, &XCUIELEMENT_IS_RESOLVED_FROM_CACHE_KEY);
}

static char XCUIELEMENT_CACHE_ID_KEY;

@dynamic fb_cacheId;

- (NSString *)fb_cacheId
{
  NSString *result = (NSString *)objc_getAssociatedObject(self, &XCUIELEMENT_IS_RESOLVED_FROM_CACHE_KEY);
  if (nil != result) {
    return result;
  }

  XCElementSnapshot *snapshot = self.fb_cachedSnapshot ?: self.fb_takeSnapshot;
  NSString *uid = snapshot.wdUID;
  objc_setAssociatedObject(self, &XCUIELEMENT_CACHE_ID_KEY, uid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return uid;
}

@end
