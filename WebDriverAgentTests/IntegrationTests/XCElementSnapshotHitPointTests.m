/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBIntegrationTestCase.h"
#import "FBMathUtils.h"
#import "FBTestMacros.h"
#import "FBMacros.h"
#import "XCElementSnapshot+FBHitpoint.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"

@interface XCElementSnapshotHitPoint : FBIntegrationTestCase
@end

@implementation XCElementSnapshotHitPoint

- (void)testAccessibilityActivationPoint
{
  if (SYSTEM_VERSION_GREATER_THAN(@"12.0")) {
    // The test is flacky on iOS 12+ in Travis env
    return;
  }
  
  [self launchApplication];
  [self goToAttributesPage];
  FBAssertWaitTillBecomesTrue(
    FBPointFuzzyEqualToPoint(self.testedApplication.buttons[@"not_accessible"]
                             .fb_lastSnapshot.fb_hitPoint.CGPointValue,
                             CGPointMake(200, 220), 0.1)
  );
}

@end
