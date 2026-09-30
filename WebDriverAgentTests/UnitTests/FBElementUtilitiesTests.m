/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import <XCTest/XCTest.h>

#import "FBElement.h"
#import "XCUIElementDouble.h"
#import "FBElementUtils.h"
#import "FBConfiguration.h"
#import "XCUIElement+FBUtilities.h"
#import <objc/runtime.h>

@interface FBQuiescenceApplicationDouble : NSObject
@property (nonatomic) BOOL fb_shouldWaitForQuiescence;
@property (nonatomic) NSTimeInterval observedTimeout;
@end
@implementation FBQuiescenceApplicationDouble
- (id)applicationImpl { return self; }
- (id)currentProcess { return self; }
- (void)fb_waitForQuiescenceIncludingAnimationsIdle:(BOOL)includingAnimations
{
  self.observedTimeout = FBConfiguration.sharedInstance.waitForIdleTimeout;
  @throw [NSException exceptionWithName:@"QuiescenceFailure" reason:@"test" userInfo:nil];
}
@end

@interface FBElementUtilitiesTests : XCTestCase
@end

@implementation FBElementUtilitiesTests

- (void)testStabilityWaitRestoresSettingsAfterAnException
{
  NSTimeInterval originalTimeout = FBConfiguration.sharedInstance.waitForIdleTimeout;
  FBQuiescenceApplicationDouble *application = [FBQuiescenceApplicationDouble new];
  XCUIElementDouble *element = [XCUIElementDouble new];
  element.application = (id)application;
  SEL selector = @selector(fb_waitUntilStableWithTimeout:);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
  void (*wait)(id, SEL, NSTimeInterval) = (void (*)(id, SEL, NSTimeInterval))
    class_getMethodImplementation(XCUIElement.class, selector);
#pragma clang diagnostic pop
  @try {
    FBConfiguration.sharedInstance.waitForIdleTimeout = 17;
    XCTAssertThrowsSpecificNamed(wait(element, selector, 2), NSException, @"QuiescenceFailure");
    XCTAssertEqual(application.observedTimeout, 2);
    XCTAssertFalse(application.fb_shouldWaitForQuiescence);
    XCTAssertEqual(FBConfiguration.sharedInstance.waitForIdleTimeout, 17);
  } @finally {
    FBConfiguration.sharedInstance.waitForIdleTimeout = originalTimeout;
  }
}

- (void)testTypesFiltering {
  NSMutableArray *elements = [NSMutableArray new];
  XCUIElementDouble *el1 = [XCUIElementDouble new];
  [elements addObject:el1];
  XCUIElementDouble *el2 = [XCUIElementDouble new];
  el2.elementType = XCUIElementTypeAlert;
  el2.wdType = @"XCUIElementTypeAlert";
  [elements addObject:el2];
  XCUIElementDouble *el3 = [XCUIElementDouble new];
  [elements addObject:el3];
  
  NSSet *result = [FBElementUtils uniqueElementTypesWithElements:elements];
  XCTAssertEqual([result count], 2);
}

@end
