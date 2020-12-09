/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "XCElementSnapshot+FBHitpoint.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"

@interface XCElementSnapshotHitPoint : FBIntegrationTestCase
@end

@implementation XCElementSnapshotHitPoint

- (void)testAccessibilityActivationPoint
{
  [self launchApplication];
  [self goToAttributesPage];
  XCUIElement *dstBtn = self.testedApplication.buttons[@"not_accessible"];
  CGPoint hitPoint = dstBtn.fb_takeSnapshot.fb_hitPoint.CGPointValue;
  XCTAssertTrue(hitPoint.x > 0 && hitPoint.y > 0);
}

@end
