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
#import "FBActiveAppDetectionPoint.h"
#import "FBExceptions.h"
#import "FBScreenRecordingRequest.h"
#import "FBScreenshot.h"
#import "XCUIScreen.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement+FBScrolling.h"

@interface FBScreenTests : FBIntegrationTestCase
@end

@implementation FBScreenTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)tearDown
{
  FBConfiguration.sharedInstance.currentDisplayId = nil;
  [super tearDown];
}

- (void)testDisplayID
{
  XCTAssertGreaterThanOrEqual([FBScreen displayID], 0LL);
}

- (void)testScreens
{
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *screens = [FBScreen screensWithError:&error];

  XCTAssertNotNil(screens);
  XCTAssertNil(error);
  XCTAssertGreaterThan(screens.count, 0UL);

  NSDictionary<NSString *, id> *mainScreen = nil;
  for (NSDictionary<NSString *, id> *screen in screens) {
    if ([screen[@"isMain"] boolValue]) {
      mainScreen = screen;
      break;
    }
  }
  XCTAssertNotNil(mainScreen);
  XCTAssertEqualObjects(mainScreen[@"displayId"], @([FBScreen displayID]));
  XCTAssertNotNil(mainScreen[@"scale"]);
  XCTAssertNotNil(mainScreen[@"bounds"]);
  XCTAssertNotNil(mainScreen[@"traits"]);
}

- (void)testScreenWithDisplayID
{
  NSError *error = nil;
  XCUIScreen *screen = [FBScreen screenWithDisplayID:[FBScreen displayID] error:&error];
  XCTAssertNil(error);
  XCTAssertEqual(screen.displayID, [FBScreen displayID]);

  XCTAssertNil([FBScreen screenWithDisplayID:[self unknownDisplayID] error:&error]);
  XCTAssertNotNil(error);
  NSMutableArray<NSNumber *> *availableIDs = [NSMutableArray array];
  for (NSDictionary<NSString *, id> *availableScreen in [FBScreen screensWithError:nil]) {
    [availableIDs addObject:availableScreen[@"displayId"]];
  }
  NSString *availableDisplays = [NSString stringWithFormat:@"Available display ids: [%@]",
                                [availableIDs componentsJoinedByString:@", "]];
  XCTAssertTrue([error.localizedDescription containsString:availableDisplays]);
}

- (void)testCurrentScreenDefaultsToMainScreen
{
  NSError *error = nil;
  XCTAssertTrue([FBScreen currentScreenWithError:&error].isMainScreen);
  XCTAssertNil(error);
}

- (void)testCurrentScreenFollowsSetting
{
  FBConfiguration.sharedInstance.currentDisplayId = @([FBScreen displayID]);
  NSError *error = nil;
  XCTAssertEqual([FBScreen currentScreenWithError:&error].displayID, [FBScreen displayID]);
  XCTAssertNil(error);
  XCTAssertNotNil([FBScreenshot takeInOriginalResolutionWithQuality:0 error:&error]);
  XCTAssertNil(error);

  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  XCTAssertNil([FBScreen currentScreenWithError:&error]);
  XCTAssertNotNil(error);
  error = nil;
  XCTAssertNil([FBScreenshot takeInOriginalResolutionWithQuality:0 error:&error]);
  XCTAssertNotNil(error);
}

- (void)testSessionResetClearsCurrentDisplay
{
  FBConfiguration.sharedInstance.currentDisplayId = @([FBScreen displayID]);
  [FBConfiguration.sharedInstance resetSessionSettings];
  XCTAssertNil(FBConfiguration.sharedInstance.currentDisplayId);
}

- (void)testSecondaryDisplayDoesNotHitTestMainDisplay
{
  NSArray<NSDictionary<NSString *, id> *> *screens = [FBScreen screensWithError:nil];
  BOOL testedSecondaryDisplay = NO;
  for (NSDictionary<NSString *, id> *screen in screens) {
    if ([screen[@"isMain"] boolValue]) {
      continue;
    }
    testedSecondaryDisplay = YES;
    FBConfiguration.sharedInstance.currentDisplayId = screen[@"displayId"];
    XCTAssertNil(FBActiveAppDetectionPoint.sharedInstance.axElement);
  }
  XCTSkipIf(!testedSecondaryDisplay, @"Requires a secondary display");
}

- (void)testActiveAppDetectionRejectsUnavailableDisplay
{
  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  XCTAssertThrowsSpecificNamed(FBActiveAppDetectionPoint.sharedInstance.axElement,
                               NSException, FBInvalidArgumentException);
}

- (void)testRecordingUsesSelectedDisplay
{
  XCTSkipIf(nil == NSClassFromString(@"XCTScreenRecordingRequest"), @"Screen recording is unavailable");
  FBScreenRecordingRequest *request = [[FBScreenRecordingRequest alloc] initWithFps:10 codec:0];
  NSError *error = nil;
  id defaultRequest = [request toNativeRequestWithError:&error];
  XCTAssertNotNil(defaultRequest);
  XCTAssertNil(error);
  XCTAssertEqualObjects([defaultRequest valueForKey:@"screenID"], @([FBScreen displayID]));

  for (NSDictionary<NSString *, id> *screen in [FBScreen screensWithError:nil]) {
    FBConfiguration.sharedInstance.currentDisplayId = screen[@"displayId"];
    id nativeRequest = [request toNativeRequestWithError:&error];
    XCTAssertNotNil(nativeRequest);
    XCTAssertNil(error);
    XCTAssertEqualObjects([nativeRequest valueForKey:@"screenID"], screen[@"displayId"]);
  }

  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  XCTAssertNil([request toNativeRequestWithError:&error]);
  XCTAssertNotNil(error);
  XCTAssertTrue([error.localizedDescription containsString:@"Available display ids"]);
}

- (long long)unknownDisplayID
{
  long long maxID = 0;
  for (NSDictionary<NSString *, id> *screen in [FBScreen screensWithError:nil]) {
    maxID = MAX(maxID, [screen[@"displayId"] longLongValue]);
  }
  return maxID + 1;
}

- (void)testScreenScale
{
  XCTAssertTrue([FBScreen scale] >= 2);
}

@end


@interface FBDisplayGestureTests : FBIntegrationTestCase
@property (nonatomic) NSNumber *previousDisplayId;
@property (nonatomic) XCUIElement *canvas;
@end

@implementation FBDisplayGestureTests

- (void)setUp
{
  [super setUp];
  self.previousDisplayId = FBConfiguration.sharedInstance.currentDisplayId;
  [self launchApplication];
  [self.testedApplication.buttons[@"coordinate-probe"] tap];
  self.canvas = self.testedApplication.otherElements[@"coordinate-canvas"];

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
  [table fb_scrollDownByNormalizedDistance:0.5];
  XCTAssertEqual(self.testedApplication.state, XCUIApplicationStateRunningForeground);
  CGFloat after = [[self measurement][@"scrollY"] doubleValue];
  XCTAssertGreaterThan(after, before + 10);
  [table fb_scrollUpByNormalizedDistance:0.5];
  XCTAssertLessThan([[self measurement][@"scrollY"] doubleValue], after - 10);
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

@end
