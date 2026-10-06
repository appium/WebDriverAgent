/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBConfiguration.h"
#import "FBScreen.h"
#import "FBExceptions.h"
#import "FBElementCommands.h"

@interface FBElementCommands (CoordinateTests)
+ (nullable XCUICoordinate *)gestureCoordinateWithOffset:(CGVector)offset element:(XCUIElement *)element error:(NSError **)error;
@end

#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement+FBScrolling.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIDevice+FBHinge.h"

@interface FBDisplayGestureTests : FBIntegrationTestCase
@property (nonatomic) NSNumber *previousDisplayId;
@property (nonatomic) XCUIElement *canvas;
@end

@implementation FBDisplayGestureTests

- (void)setUp
{
  [super setUp];
  self.previousDisplayId = FBConfiguration.sharedInstance.currentDisplayId;
  if (!XCUIDevice.sharedDevice.fb_canAttemptSimulatedHingeAngleInjection) {
    [self resetOrientation];
  }
  [self launchApplication];
  [self.testedApplication.buttons[@"coordinate-probe"] tap];
  self.canvas = self.testedApplication.otherElements[@"coordinate-canvas"];

  [self selectFixtureDisplay];
}

- (void)selectFixtureDisplay
{
  // The fixture reports the screen it actually occupies. Do not assume the main
  // screen is active: Duo changes displays when its hinge changes position.
  NSArray<NSNumber *> *size = [self measurement][@"screenSize"];
  NSNumber *displayId = nil;
  for (NSDictionary *screen in [FBScreen screensWithError:nil]) {
    CGFloat width = [screen[@"bounds"][@"width"] doubleValue] / [screen[@"scale"] doubleValue];
    CGFloat height = [screen[@"bounds"][@"height"] doubleValue] / [screen[@"scale"] doubleValue];
    if (fabs(MAX(width, height) - MAX(size[0].doubleValue, size[1].doubleValue)) < 1
        && fabs(MIN(width, height) - MIN(size[0].doubleValue, size[1].doubleValue)) < 1) {
      displayId = screen[@"displayId"];
      break;
    }
  }
  XCTAssertNotNil(displayId, @"Cannot identify the fixture's display");
  FBConfiguration.sharedInstance.currentDisplayId = displayId;
}

- (void)tearDown
{
  FBConfiguration.sharedInstance.currentDisplayId = self.previousDisplayId;
  [super tearDown];
}

- (NSDictionary *)measurement
{
  NSString *value = self.testedApplication.staticTexts[@"probe-status"].label;
  NSError *error = nil;
  NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:0 error:&error];
  XCTAssertNil(error);
  return result;
}

- (void)performMoves:(NSArray<NSDictionary *> *)moves expectedEnd:(CGPoint)expected
{
  NSUInteger count = [[self measurement][@"count"] unsignedIntegerValue];
  NSMutableArray *items = [NSMutableArray arrayWithArray:@[
    moves.firstObject,
    @{@"type": @"pointerDown", @"button": @0},
    @{@"type": @"pause", @"duration": @100},
  ]];
  if (moves.count > 1) {
    [items addObjectsFromArray:[moves subarrayWithRange:NSMakeRange(1, moves.count - 1)]];
  }
  [items addObject:@{@"type": @"pointerUp", @"button": @0}];
  NSError *error = nil;
  NSArray *actions = @[@{
    @"type": @"pointer", @"id": @"finger", @"parameters": @{@"pointerType": @"touch"}, @"actions": items,
  }];
  XCTAssertTrue([self.testedApplication fb_performW3CActions:actions elementCache:nil error:&error], @"%@", error);
  NSDictionary *result = [self measurement];
  XCTAssertEqual([result[@"count"] unsignedIntegerValue], count + 1);
  XCTAssertEqualObjects(result[@"phase"], @"ended");
  NSArray<NSNumber *> *actual = result[@"last"];
  XCTAssertEqualWithAccuracy(actual[0].doubleValue, expected.x, 1);
  XCTAssertEqualWithAccuracy(actual[1].doubleValue, expected.y, 1);
}

- (NSDictionary *)moveFrom:(id)origin x:(CGFloat)x y:(CGFloat)y duration:(NSUInteger)duration
{
  return @{@"type": @"pointerMove", @"origin": origin, @"x": @(x), @"y": @(y), @"duration": @(duration)};
}

- (void)testNativeApplicationCoordinates
{
  NSDictionary *geometry = [self measurement];
  NSArray<NSNumber *> *bounds = geometry[@"canvasBounds"];
  NSArray<NSNumber *> *frame = geometry[@"canvasWindowRect"];
  for (NSNumber *x in @[@40, @(bounds[0].doubleValue - 40)]) {
    for (NSNumber *y in @[@40, @(bounds[1].doubleValue - 40)]) {
      NSUInteger count = [[self measurement][@"count"] unsignedIntegerValue];
      NSError *error = nil;
      XCUICoordinate *coordinate = [FBElementCommands gestureCoordinateWithOffset:
        CGVectorMake(frame[0].doubleValue + x.doubleValue, frame[1].doubleValue + y.doubleValue)
        element:self.testedApplication error:&error];
      XCTAssertNotNil(coordinate);
      XCTAssertNil(error);
      [coordinate tap];
      NSDictionary *result = [self measurement];
      XCTAssertEqual([result[@"count"] unsignedIntegerValue], count + 1);
      XCTAssertEqualWithAccuracy([result[@"last"][0] doubleValue], x.doubleValue, 1);
      XCTAssertEqualWithAccuracy([result[@"last"][1] doubleValue], y.doubleValue, 1);
    }
  }
}

- (void)testViewportAndElementCorners
{
  NSDictionary *geometry = [self measurement];
  NSArray<NSNumber *> *bounds = geometry[@"canvasBounds"];
  NSArray<NSNumber *> *frame = geometry[@"canvasWindowRect"];
  CGFloat width = bounds[0].doubleValue, height = bounds[1].doubleValue;
  for (NSNumber *x in @[@40, @(width - 40)]) {
    for (NSNumber *y in @[@40, @(height - 40)]) {
      CGPoint point = CGPointMake(x.doubleValue, y.doubleValue);
      [self performMoves:@[[self moveFrom:@"viewport"
                                       x:frame[0].doubleValue + point.x y:frame[1].doubleValue + point.y duration:0]]
              expectedEnd:point];
      [self performMoves:@[[self moveFrom:self.canvas x:point.x - width / 2 y:point.y - height / 2 duration:0]]
              expectedEnd:point];
    }
  }
}

- (void)testElementHitpoint
{
  NSArray<NSNumber *> *bounds = [self measurement][@"canvasBounds"];
  [self performMoves:@[@{@"type": @"pointerMove", @"origin": self.canvas, @"duration": @0}]
          expectedEnd:CGPointMake(bounds[0].doubleValue / 2, bounds[1].doubleValue / 2)];
}

- (void)testPointerRelativeMovesPreserveOriginSpace
{
  NSDictionary *geometry = [self measurement];
  NSArray<NSNumber *> *bounds = geometry[@"canvasBounds"];
  NSArray<NSNumber *> *frame = geometry[@"canvasWindowRect"];
  CGPoint center = CGPointMake(bounds[0].doubleValue / 2, bounds[1].doubleValue / 2);
  for (NSDictionary *start in @[
    [self moveFrom:self.canvas x:0 y:0 duration:0],
    [self moveFrom:@"viewport" x:frame[0].doubleValue + center.x y:frame[1].doubleValue + center.y duration:0],
  ]) {
    [self performMoves:@[start,
                         [self moveFrom:@"pointer" x:0 y:-40 duration:200],
                         [self moveFrom:@"pointer" x:0 y:-40 duration:200]]
            expectedEnd:CGPointMake(center.x, center.y - 80)];
  }
}

- (void)testMixedOriginsWithinOneTouch
{
  NSDictionary *geometry = [self measurement];
  NSArray<NSNumber *> *bounds = geometry[@"canvasBounds"];
  NSArray<NSNumber *> *frame = geometry[@"canvasWindowRect"];
  CGPoint center = CGPointMake(bounds[0].doubleValue / 2, bounds[1].doubleValue / 2);
  for (NSNumber *startAtElement in @[@YES, @NO]) {
    NSDictionary *start = startAtElement.boolValue
      ? [self moveFrom:self.canvas x:0 y:0 duration:0]
      : [self moveFrom:@"viewport" x:frame[0].doubleValue + center.x y:frame[1].doubleValue + center.y duration:0];
    NSDictionary *next = startAtElement.boolValue
      ? [self moveFrom:@"viewport" x:frame[0].doubleValue + center.x y:frame[1].doubleValue + center.y - 40 duration:200]
      : [self moveFrom:self.canvas x:0 y:-40 duration:200];
    [self performMoves:@[start, next, [self moveFrom:@"pointer" x:0 y:-40 duration:200]]
            expectedEnd:CGPointMake(center.x, center.y - 80)];
  }
}

- (void)testScrollRemainsInForegroundAndMovesContent
{
  [self.testedApplication.buttons[@"Scroll"] tap];
  XCUIElement *table = self.testedApplication.tables[@"probe-table"];
  CGFloat before = [[self measurement][@"scrollY"] doubleValue];
  // Exceeds the per-drag limit, exercising multiple drags in one coordinate space.
  [table fb_scrollDownByNormalizedDistance:1.0];
  XCTAssertEqual(self.testedApplication.state, XCUIApplicationStateRunningForeground);
  CGFloat after = [[self measurement][@"scrollY"] doubleValue];
  XCTAssertGreaterThan(after, before + 10);
  [table fb_scrollUpByNormalizedDistance:0.5];
  XCTAssertLessThan([[self measurement][@"scrollY"] doubleValue], after - 10);
}

- (void)testDirectionalScrollRejectsUnavailableDisplay
{
  [self.testedApplication.buttons[@"Scroll"] tap];
  XCUIElement *table = self.testedApplication.tables[@"probe-table"];
  CGFloat before = [[self measurement][@"scrollY"] doubleValue];
  NSNumber *displayId = FBConfiguration.sharedInstance.currentDisplayId;
  @try {
    FBConfiguration.sharedInstance.currentDisplayId = @(-1);
    XCTAssertThrowsSpecificNamed([table fb_scrollDownByNormalizedDistance:0.5], NSException, FBInvalidArgumentException);
    XCTAssertThrowsSpecificNamed([table fb_scrollUpByNormalizedDistance:0.5], NSException, FBInvalidArgumentException);
    XCTAssertThrowsSpecificNamed([table fb_scrollLeftByNormalizedDistance:0.5], NSException, FBInvalidArgumentException);
    XCTAssertThrowsSpecificNamed([table fb_scrollRightByNormalizedDistance:0.5], NSException, FBInvalidArgumentException);
  } @finally {
    FBConfiguration.sharedInstance.currentDisplayId = displayId;
  }
  XCTAssertEqualWithAccuracy([[self measurement][@"scrollY"] doubleValue], before, 1);
}

- (void)testScrollToElementRejectsUnavailableDisplay
{
  [self.testedApplication.buttons[@"Scroll"] tap];
  XCUIElement *cell = self.testedApplication.cells[@"probe-row-13"];
  NSNumber *displayId = FBConfiguration.sharedInstance.currentDisplayId;
  @try {
    FBConfiguration.sharedInstance.currentDisplayId = @(-1);
    NSError *error = nil;
    XCTAssertFalse([cell fb_scrollToVisibleWithError:&error]);
    XCTAssertNotNil(error);
  } @finally {
    FBConfiguration.sharedInstance.currentDisplayId = displayId;
  }
}

- (void)testScrollToElementKeepsTheWholeCellVisible
{
  [self.testedApplication.buttons[@"Scroll"] tap];
  XCUIElement *cell = self.testedApplication.cells[@"probe-row-13"];
  NSError *error = nil;
  XCTAssertTrue([cell fb_scrollToVisibleWithError:&error], @"%@", error);
  XCTAssertEqual(self.testedApplication.state, XCUIApplicationStateRunningForeground);
  NSArray<NSNumber *> *frame = [self measurement][@"canvasWindowRect"];
  XCTAssertTrue(cell.hittable);
  XCTAssertGreaterThanOrEqual(CGRectGetMinY(cell.frame), frame[1].doubleValue - 1);
  XCTAssertLessThanOrEqual(CGRectGetMaxY(cell.frame), frame[1].doubleValue + frame[3].doubleValue + 1);
}

- (void)verifyLandscapeScrolling:(UIDeviceOrientation)orientation
{
  XCTSkipIf(XCUIDevice.sharedDevice.fb_canAttemptSimulatedHingeAngleInjection,
            @"Foldable simulator orientations are covered by testGesturesAcrossFoldStates");
  UIDeviceOrientation previousOrientation = XCUIDevice.sharedDevice.orientation;
  [self addTeardownBlock:^{
    [XCUIDevice.sharedDevice fb_setDeviceInterfaceOrientation:previousOrientation];
  }];
  XCTAssertTrue([[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation]);
  [self.testedApplication.buttons[@"Scroll"] tap];
  XCUIElement *table = self.testedApplication.tables[@"probe-table"];
  // Choose a nearby offscreen row: the phone's landscape table is intentionally
  // short, and this test checks coordinates rather than the 25-scroll limit.
  NSUInteger row = (NSUInteger)ceil(table.frame.size.height / 44) + 2;
  XCUIElement *cell = self.testedApplication.cells[[NSString stringWithFormat:@"probe-row-%lu", (unsigned long)row]];
  NSError *error = nil;
  XCTAssertTrue([cell fb_scrollToVisibleWithError:&error], @"%@", error);
  XCTAssertEqual(self.testedApplication.state, XCUIApplicationStateRunningForeground);
  XCTAssertGreaterThan([[self measurement][@"scrollY"] doubleValue], 10);
  XCTAssertTrue([[self measurement][@"fullyVisibleRows"] containsObject:@(row)]);
  XCTAssertTrue(cell.hittable);
  XCTAssertGreaterThanOrEqual(CGRectGetMinY(cell.frame), CGRectGetMinY(table.frame) - 1);
  XCTAssertLessThanOrEqual(CGRectGetMaxY(cell.frame), CGRectGetMaxY(table.frame) + 1);
}

- (void)testScrollToElementInLandscapeLeft
{
  [self verifyLandscapeScrolling:UIDeviceOrientationLandscapeLeft];
}

- (void)testScrollToElementInLandscapeRight
{
  [self verifyLandscapeScrolling:UIDeviceOrientationLandscapeRight];
}

- (void)testGesturesAcrossFoldStates
{
  XCUIDevice *device = XCUIDevice.sharedDevice;
  XCTSkipIf(!device.fb_canAttemptSimulatedHingeAngleInjection, @"Requires a foldable simulator");
  NSError *error = nil;
  NSNumber *originalAngle = [device fb_getSimulatedHingeAngle:&error];
  XCTAssertNotNil(originalAngle, @"%@", error);
  [self addTeardownBlock:^{
    if (nil != originalAngle) {
      [device fb_setSimulatedHingeAngle:originalAngle.doubleValue error:nil];
    }
  }];
  for (NSNumber *angle in @[@0, @90, @180, @0]) {
    [self.testedApplication terminate];
    XCTAssertTrue([device fb_setSimulatedHingeAngle:angle.doubleValue error:&error], @"%@", error);
    [self launchApplication];
    [self.testedApplication.buttons[@"coordinate-probe"] tap];
    self.canvas = self.testedApplication.otherElements[@"coordinate-canvas"];
    [self selectFixtureDisplay];
    NSDictionary *geometry = [self measurement];
    NSArray<NSNumber *> *bounds = geometry[@"canvasBounds"];
    NSArray<NSNumber *> *frame = geometry[@"canvasWindowRect"];
    CGPoint center = CGPointMake(bounds[0].doubleValue / 2, bounds[1].doubleValue / 2);
    [self performMoves:@[[self moveFrom:@"viewport" x:frame[0].doubleValue + center.x
                                      y:frame[1].doubleValue + center.y duration:0],
                         [self moveFrom:self.canvas x:0 y:-20 duration:200],
                         [self moveFrom:@"pointer" x:0 y:-20 duration:200]]
            expectedEnd:CGPointMake(center.x, center.y - 40)];
    [self.testedApplication.buttons[@"Scroll"] tap];
    XCUIElement *table = self.testedApplication.tables[@"probe-table"];
    [table fb_scrollDownByNormalizedDistance:1.0];
    XCTAssertGreaterThan([[self measurement][@"scrollY"] doubleValue], 10);
    XCTAssertEqual(self.testedApplication.state, XCUIApplicationStateRunningForeground);
  }
}

@end
