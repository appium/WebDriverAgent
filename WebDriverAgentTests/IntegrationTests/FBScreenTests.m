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
#import "FBRunLoopSpinner.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIDevice+FBHinge.h"
#import "XCUIElement.h"
#import "FBActiveAppDetectionPoint.h"
#import "FBExceptions.h"
#import "FBScreenRecordingRequest.h"
#import "FBScreenshot.h"
#import "XCUIScreen.h"
#import "FBCustomCommands.h"
#import "FBRouteRequest.h"
#import "FBResponsePayload.h"
#import "RouteResponse.h"

@interface FBCustomCommands (FBScreenInfoTesting)
+ (id<FBResponsePayload>)handleGetScreen:(FBRouteRequest *)request;
@end

@interface FBScreen (FBLookupTesting)
+ (nullable XCUIScreen *)screenWithDisplayID:(long long)displayID device:(id)device error:(NSError **)error;
@end

@interface FBEmptyScreenDouble : NSObject
@property (nonatomic) CGRect bounds;
@end
@implementation FBEmptyScreenDouble
@end

@interface FBScreenDeviceDouble : NSObject
@property (nonatomic) BOOL nativeLookupAvailable;
@property (nonatomic) BOOL enumerationUnavailable;
@property (nonatomic) NSUInteger enumerationCount;
@property (nonatomic, strong) XCUIScreen *nativeScreen;
@property (nonatomic, strong) NSArray<XCUIScreen *> *screens;
@property (nonatomic, strong) NSError *lookupError;
@property (nonatomic, strong) NSError *enumerationError;
@end

@implementation FBScreenDeviceDouble
- (BOOL)respondsToSelector:(SEL)selector
{
  if (selector == NSSelectorFromString(@"screensOrError:") && self.enumerationUnavailable) {
    return NO;
  }
  return selector == @selector(screenWithDisplayID:orError:)
    ? self.nativeLookupAvailable : [super respondsToSelector:selector];
}
- (XCUIScreen *)screenWithDisplayID:(long long)displayID orError:(NSError **)error
{
  if (NULL != error) {
    *error = self.lookupError;
  }
  return self.nativeScreen;
}
- (NSArray<XCUIScreen *> *)screensOrError:(NSError **)error
{
  self.enumerationCount++;
  if (NULL != error) {
    *error = self.enumerationError;
  }
  return self.screens;
}
@end

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
  for (NSDictionary<NSString *, id> *entry in [FBScreen screensWithError:&error]) {
    long long displayID = [entry[@"displayId"] longLongValue];
    XCUIScreen *screen = [FBScreen screenWithDisplayID:displayID error:&error];
    XCTAssertNotNil(screen);
    XCTAssertNil(error);
    XCTAssertEqual(screen.displayID, displayID);
  }

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

- (void)testNativeScreenLookupDoesNotEnumerateOnSuccess
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.nativeLookupAvailable = YES;
  device.nativeScreen = XCUIScreen.mainScreen;
  NSError *error = nil;
  XCTAssertEqualObjects([FBScreen screenWithDisplayID:device.nativeScreen.displayID device:device error:&error],
                        device.nativeScreen);
  XCTAssertNil(error);
  XCTAssertEqual(device.enumerationCount, 0UL);
}

- (void)testNativeScreenPlaceholderMustBeAvailable
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.nativeLookupAvailable = YES;
  device.nativeScreen = (id)[FBEmptyScreenDouble new];
  device.screens = @[XCUIScreen.mainScreen];
  NSError *error = nil;
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual(device.enumerationCount, 1UL);
}

- (void)testNativeScreenLookupFailureIncludesAvailableIDs
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.nativeLookupAvailable = YES;
  device.screens = @[XCUIScreen.mainScreen];
  device.lookupError = [NSError errorWithDomain:@"NativeLookup" code:1 userInfo:nil];
  NSError *error = nil;
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertEqual(device.enumerationCount, 1UL);
  XCTAssertTrue([error.localizedDescription containsString:@"Available display ids"]);
  XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], device.lookupError);
}

- (void)testNativeScreenLookupErrorSurvivesEnumerationFailure
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.nativeLookupAvailable = YES;
  device.lookupError = [NSError errorWithDomain:@"NativeLookup" code:1 userInfo:nil];
  device.enumerationError = [NSError errorWithDomain:@"Enumeration" code:2 userInfo:nil];
  NSError *error = nil;
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertEqualObjects(error, device.lookupError);
}

- (void)testScreenLookupWithoutNativeSelector
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.screens = @[XCUIScreen.mainScreen];
  NSError *error = nil;
  XCTAssertEqualObjects([FBScreen screenWithDisplayID:XCUIScreen.mainScreen.displayID device:device error:&error],
                        XCUIScreen.mainScreen);
  XCTAssertNil(error);
  XCTAssertEqual(device.enumerationCount, 1UL);
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertTrue([error.localizedDescription containsString:@"Available display ids"]);
  device.screens = nil;
  device.enumerationError = [NSError errorWithDomain:@"Enumeration" code:2 userInfo:nil];
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertEqualObjects(error, device.enumerationError);
}

- (void)testScreenLookupWithoutDeviceScreenSelectors
{
  FBScreenDeviceDouble *device = [FBScreenDeviceDouble new];
  device.enumerationUnavailable = YES;
  NSError *error = nil;
  XCTAssertEqualObjects([FBScreen screenWithDisplayID:XCUIScreen.mainScreen.displayID device:device error:&error],
                        XCUIScreen.mainScreen);
  XCTAssertNil(error);
  XCTAssertNil([FBScreen screenWithDisplayID:-1 device:device error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual(device.enumerationCount, 0UL);
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

- (NSDictionary *)screenInfoResponse
{
  FBRouteRequest *request = [FBRouteRequest routeRequestWithURL:[NSURL URLWithString:@"http://localhost:8100/wda/screen"]
                                                  parameters:@{}
                                                   arguments:@{}];
  RouteResponse *response = [RouteResponse new];
  [[FBCustomCommands handleGetScreen:request] dispatchWithResponse:response];
  return [NSJSONSerialization JSONObjectWithData:response.responseData options:0 error:nil][@"value"];
}

- (void)testScreenInfoFollowsDisplaySelection
{
  for (NSDictionary *screen in [FBScreen screensWithError:nil]) {
    FBConfiguration.sharedInstance.currentDisplayId = screen[@"displayId"];
    NSDictionary *info = [self screenInfoResponse];
    XCTAssertNil(info[@"error"]);
    XCTAssertEqualObjects(info[@"displayId"], screen[@"displayId"]);
    XCTAssertEqualObjects(info[@"scale"], screen[@"scale"]);
    double width = [info[@"screenSize"][@"width"] doubleValue];
    double height = [info[@"screenSize"][@"height"] doubleValue];
    double scale = [screen[@"scale"] doubleValue];
    double expectedWidth = [screen[@"bounds"][@"width"] doubleValue] / scale;
    double expectedHeight = [screen[@"bounds"][@"height"] doubleValue] / scale;
    XCTAssertEqualWithAccuracy(MIN(width, height), MIN(expectedWidth, expectedHeight), 0.01);
    XCTAssertEqualWithAccuracy(MAX(width, height), MAX(expectedWidth, expectedHeight), 0.01);
    double barHeight = [info[@"statusBarSize"][@"height"] doubleValue];
    XCTAssertGreaterThanOrEqual(barHeight, 0);
    XCTAssertLessThan(barHeight, height);
    if (barHeight > 0) {
      XCTAssertEqualWithAccuracy([info[@"statusBarSize"][@"width"] doubleValue], width, 1);
    }
  }
  // tearDown restores the default display even when an assertion fails.
}

- (void)testScreenInfoFollowsDisplayReset
{
  // Exercise reset independently of the display-selection assertions.
  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  FBConfiguration.sharedInstance.currentDisplayId = nil;
  XCTAssertEqualObjects([self screenInfoResponse][@"displayId"], @([FBScreen displayID]));
}

- (void)testScreenInfoRejectsUnavailableDisplay
{
  FBConfiguration.sharedInstance.currentDisplayId = @([self unknownDisplayID]);
  NSDictionary *info = [self screenInfoResponse];
  XCTAssertEqualObjects(info[@"error"], @"invalid argument");
  XCTAssertTrue([info[@"message"] containsString:@"Available display ids"]);
}

- (void)testScreenInfoInBothLandscapeOrientations
{
  XCTSkipIf(XCUIDevice.sharedDevice.fb_canAttemptSimulatedHingeAngleInjection,
            @"Foldable orientations are covered by testScreenInfoAcrossFoldStates");
  XCUIElement *window = self.testedApplication.windows.firstMatch;
  (void)window.frame;
  XCTSkipIf(window.screen.displayID != XCUIScreen.mainScreen.displayID,
            @"Requires the fixture on the main display");
  [self addTeardownBlock:^{
    [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:UIDeviceOrientationPortrait];
  }];
  BOOL expectsVisibleBar = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
  for (NSNumber *orientation in @[@(UIDeviceOrientationLandscapeLeft), @(UIDeviceOrientationLandscapeRight)]) {
    XCTAssertTrue([[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation.integerValue]);
    __block NSDictionary *info = nil;
    // iPad keeps its top status bar in landscape. Wait for rotation to finish
    // rather than accepting a transient zero crop as a successful result.
    XCTAssertTrue([[[FBRunLoopSpinner new] timeout:5] spinUntilTrue:^BOOL {
      info = [self screenInfoResponse];
      double width = [info[@"screenSize"][@"width"] doubleValue];
      double height = [info[@"screenSize"][@"height"] doubleValue];
      double barWidth = [info[@"statusBarSize"][@"width"] doubleValue];
      double barHeight = [info[@"statusBarSize"][@"height"] doubleValue];
      if (nil != info[@"error"] || width <= height || height <= 0) {
        return NO;
      }
      if (barHeight == 0) {
        return !expectsVisibleBar && barWidth == 0;
      }
      return barHeight > 0 && barHeight < height && fabs(barWidth - width) <= 1;
    }], @"Unexpected landscape screen metadata: %@", info);
  }
}

- (void)testScreenInfoAcrossFoldStates
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
    XCUIElement *window = self.testedApplication.windows.firstMatch;
    CGRect frame = window.frame;
    FBConfiguration.sharedInstance.currentDisplayId = @(window.screen.displayID);
    __block NSDictionary *info = nil;
    XCTAssertTrue([[[FBRunLoopSpinner new] timeout:5] spinUntilTrue:^BOOL {
      info = [self screenInfoResponse];
      double width = [info[@"screenSize"][@"width"] doubleValue];
      double height = [info[@"screenSize"][@"height"] doubleValue];
      double barHeight = [info[@"statusBarSize"][@"height"] doubleValue];
      return nil == info[@"error"] && fabs(width - frame.size.width) <= 1
        && fabs(height - frame.size.height) <= 1
        && barHeight >= 0 && barHeight < height
        && (barHeight == 0 || fabs([info[@"statusBarSize"][@"width"] doubleValue] - width) <= 1)
        && (angle.doubleValue == 0 || barHeight == 0);
    }], @"Unexpected screen metadata at hinge angle %@: %@", angle, info);
  }
}

- (void)testScreenInfoIncludesTopStatusBarOnSingleDisplay
{
  XCTSkipIf([FBScreen screensWithError:nil].count != 1, @"Requires a single-display device");
  // The integration fixture uses the ordinary visible portrait status bar.
  // An unresolved XCUIElement has displayID == 0; it must not be filtered out.
  NSDictionary *info = [self screenInfoResponse];
  XCTAssertGreaterThan([info[@"statusBarSize"][@"height"] doubleValue], 0);
  XCTAssertEqualWithAccuracy([info[@"statusBarSize"][@"width"] doubleValue],
                            [info[@"screenSize"][@"width"] doubleValue], 1);
}

@end
