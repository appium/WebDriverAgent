/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "../IntegrationApp/Classes/TouchableView.h"

// Only the location and identity are needed to replay UIKit's touch callbacks.
@interface FBFixtureTouchDouble : NSObject
@end

@implementation FBFixtureTouchDouble
- (CGPoint)locationInView:(UIView *)view
{
  return CGPointMake(50, 50);
}
@end

@interface FBTouchableViewTests : XCTestCase <TouchableViewDelegate>
@property (nonatomic, strong) TouchableView *touchable;
@property (nonatomic) int reportedTouches;
@property (nonatomic) int reportedTaps;
@end

@implementation FBTouchableViewTests

- (void)setUp
{
  [super setUp];
  self.reportedTouches = 0;
  self.reportedTaps = 0;
  self.touchable = [[TouchableView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
  self.touchable.delegate = self;
}

- (void)tearDown
{
  self.touchable.delegate = nil;
  self.touchable = nil;
  [super tearDown];
}

- (void)shouldHandleTouchesNumber:(int)touchesCount
{
  self.reportedTouches = touchesCount;
}

- (void)shouldHandleTapsNumber:(int)numberOfTaps
{
  self.reportedTaps = numberOfTaps;
}

- (UITouch *)newTouch
{
  return (UITouch *)[FBFixtureTouchDouble new];
}

- (void)testStaggeredTouchesTrackActiveFingers
{
  NSSet *first = [NSSet setWithObject:[self newTouch]];
  NSSet *second = [NSSet setWithObject:[self newTouch]];
  [self.touchable touchesBegan:first withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 1);
  [self.touchable touchesBegan:second withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 2);
  XCTAssertEqual(self.reportedTaps, 0);

  [self.touchable touchesEnded:first withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 1);
  XCTAssertEqual(self.reportedTaps, 1);
  [self.touchable touchesEnded:second withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 0);
  XCTAssertEqual(self.reportedTaps, 2);
}

- (void)testSimultaneousContactsCountIndependentlyOfCallbackBatching
{
  NSSet *touches = [NSSet setWithObjects:[self newTouch], [self newTouch], nil];
  [self.touchable touchesBegan:touches withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 2);
  [self.touchable touchesEnded:touches withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 0);
  XCTAssertEqual(self.reportedTaps, 2);
}

- (void)testCancelledContactsDoNotCarryOverIntoNextTap
{
  NSSet *first = [NSSet setWithObject:[self newTouch]];
  NSSet *second = [NSSet setWithObject:[self newTouch]];
  [self.touchable touchesBegan:first withEvent:nil];
  [self.touchable touchesBegan:second withEvent:nil];
  [self.touchable touchesCancelled:[first setByAddingObjectsFromSet:second] withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 0);
  XCTAssertEqual(self.reportedTaps, 0);

  NSSet *next = [NSSet setWithObject:[self newTouch]];
  [self.touchable touchesBegan:next withEvent:nil];
  [self.touchable touchesEnded:next withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 0);
  XCTAssertEqual(self.reportedTaps, 1);
}

- (void)testCancellingOneFingerPreservesTheOtherContact
{
  NSSet *first = [NSSet setWithObject:[self newTouch]];
  NSSet *second = [NSSet setWithObject:[self newTouch]];
  [self.touchable touchesBegan:[first setByAddingObjectsFromSet:second] withEvent:nil];
  [self.touchable touchesCancelled:first withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 1);
  XCTAssertEqual(self.reportedTaps, 0);
  [self.touchable touchesEnded:second withEvent:nil];
  XCTAssertEqual(self.reportedTouches, 0);
  XCTAssertEqual(self.reportedTaps, 1);
}

@end
