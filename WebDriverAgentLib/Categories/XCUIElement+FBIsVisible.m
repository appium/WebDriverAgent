/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBIsVisible.h"

#import "FBConfiguration.h"
#import "FBElementUtils.h"
#import "FBMathUtils.h"
#import "FBActiveAppDetectionPoint.h"
#import "FBSession.h"
#import "FBXCAccessibilityElement.h"
#import "FBXCodeCompatibility.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBUID.h"
#import "XCTestPrivateSymbols.h"

@implementation XCUIElement (FBIsVisible)

- (BOOL)fb_isVisible
{
  id<FBXCElementSnapshot> snapshot = [self fb_snapshotWithCustomAttributes:@[FB_XCAXAIsVisibleAttributeName]
                                                exludingStandardAttributes:YES
                                                                   inDepth:NO];
  return [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_isVisible;
}

@end

@implementation FBXCElementSnapshotWrapper (FBIsVisible)

- (BOOL)fb_isVisible
{
  NSNumber *isVisible = self.additionalAttributes[FB_XCAXAIsVisibleAttribute];
  if (isVisible != nil) {
    return isVisible.boolValue;
  }

  return [(NSNumber *)[self fb_attributeValue:FB_XCAXAIsVisibleAttributeName] boolValue];
}

@end
