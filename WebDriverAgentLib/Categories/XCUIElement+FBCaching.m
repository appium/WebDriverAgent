/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIElement+FBCaching.h"

#import <objc/runtime.h>

#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBUID.h"

@implementation XCUIElement (FBCaching)

static char XCUIELEMENT_CACHE_ID_KEY;

@dynamic fb_cacheId;

- (NSString *)fb_cacheId
{
  id result = objc_getAssociatedObject(self, &XCUIELEMENT_CACHE_ID_KEY);
  if ([result isKindOfClass:NSString.class]) {
    return (NSString *)result;
  }

  NSString *uid = self.fb_uid;
  objc_setAssociatedObject(self, &XCUIELEMENT_CACHE_ID_KEY, uid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return uid;
}

@end
