/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBElementCommands.h"

#import "FBConfiguration.h"
#import "FBKeyboard.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBElementCache.h"
#import "FBErrorBuilder.h"
#import "FBSession.h"
#import "FBElementUtils.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRuntimeUtils.h"
#import "NSPredicate+FBFormat.h"
#import "XCTestPrivateSymbols.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBPickerWheel.h"
#import "XCUIElement+FBScrolling.h"
#import "XCUIElement+FBForceTouch.h"
#import "XCUIElement+FBSwiping.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBTVFocuse.h"
#import "XCUIElement+FBResolve.h"
#import "XCUIElement+FBUID.h"
#import "FBElementTypeTransformer.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"
#import "FBXCodeCompatibility.h"

@interface FBElementCommands ()
@end

@implementation FBElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/window/size"] respondWithTarget:self action:@selector(handleGetWindowSize:)],
    [[FBRoute GET:@"/window/rect"] respondWithTarget:self action:@selector(handleGetWindowRect:)],
    [[FBRoute GET:@"/window/size"].withoutSession respondWithTarget:self action:@selector(handleGetWindowSize:)],
    [[FBRoute GET:@"/element/:uuid/enabled"] respondWithTarget:self action:@selector(handleGetEnabled:)],
    [[FBRoute GET:@"/element/:uuid/rect"] respondWithTarget:self action:@selector(handleGetRect:)],
    [[FBRoute GET:@"/element/:uuid/attribute/:name"] respondWithTarget:self action:@selector(handleGetAttribute:)],
    [[FBRoute GET:@"/element/:uuid/text"] respondWithTarget:self action:@selector(handleGetText:)],
    [[FBRoute GET:@"/element/:uuid/displayed"] respondWithTarget:self action:@selector(handleGetDisplayed:)],
    [[FBRoute GET:@"/element/:uuid/selected"] respondWithTarget:self action:@selector(handleGetSelected:)],
    [[FBRoute GET:@"/element/:uuid/name"] respondWithTarget:self action:@selector(handleGetName:)],
    [[FBRoute POST:@"/element/:uuid/value"] respondWithTarget:self action:@selector(handleSetValue:)],
    [[FBRoute POST:@"/element/:uuid/click"] respondWithTarget:self action:@selector(handleClick:)],
    [[FBRoute POST:@"/element/:uuid/clear"] respondWithTarget:self action:@selector(handleClear:)],
    // W3C element screenshot
    [[FBRoute GET:@"/element/:uuid/screenshot"] respondWithTarget:self action:@selector(handleElementScreenshot:)],
    // JSONWP element screenshot
    [[FBRoute GET:@"/screenshot/:uuid"] respondWithTarget:self action:@selector(handleElementScreenshot:)],
    [[FBRoute GET:@"/wda/element/:uuid/accessible"] respondWithTarget:self action:@selector(handleGetAccessible:)],
    [[FBRoute GET:@"/wda/element/:uuid/accessibilityContainer"] respondWithTarget:self action:@selector(handleGetIsAccessibilityContainer:)],
#if TARGET_OS_TV
    [[FBRoute GET:@"/element/:uuid/attribute/focused"] respondWithTarget:self action:@selector(handleGetFocused:)],
    [[FBRoute POST:@"/wda/element/:uuid/focuse"] respondWithTarget:self action:@selector(handleFocuse:)],
#else
    [[FBRoute POST:@"/wda/element/:uuid/swipe"] respondWithTarget:self action:@selector(handleSwipe:)],
    [[FBRoute POST:@"/wda/swipe"] respondWithTarget:self action:@selector(handleSwipe:)],

    [[FBRoute POST:@"/wda/element/:uuid/pinch"] respondWithTarget:self action:@selector(handlePinch:)],
    [[FBRoute POST:@"/wda/pinch"] respondWithTarget:self action:@selector(handlePinch:)],

    [[FBRoute POST:@"/wda/element/:uuid/rotate"] respondWithTarget:self action:@selector(handleRotate:)],
    [[FBRoute POST:@"/wda/rotate"] respondWithTarget:self action:@selector(handleRotate:)],

    [[FBRoute POST:@"/wda/element/:uuid/doubleTap"] respondWithTarget:self action:@selector(handleDoubleTap:)],
    [[FBRoute POST:@"/wda/doubleTap"] respondWithTarget:self action:@selector(handleDoubleTap:)],

    [[FBRoute POST:@"/wda/element/:uuid/twoFingerTap"] respondWithTarget:self action:@selector(handleTwoFingerTap:)],
    [[FBRoute POST:@"/wda/twoFingerTap"] respondWithTarget:self action:@selector(handleTwoFingerTap:)],

    [[FBRoute POST:@"/wda/element/:uuid/tapWithNumberOfTaps"] respondWithTarget:self
                                                                         action:@selector(handleTapWithNumberOfTaps:)],
    [[FBRoute POST:@"/wda/tapWithNumberOfTaps"] respondWithTarget:self
                                                           action:@selector(handleTapWithNumberOfTaps:)],

    [[FBRoute POST:@"/wda/element/:uuid/touchAndHold"] respondWithTarget:self action:@selector(handleTouchAndHold:)],
    [[FBRoute POST:@"/wda/touchAndHold"] respondWithTarget:self action:@selector(handleTouchAndHold:)],

    [[FBRoute POST:@"/wda/element/:uuid/scroll"] respondWithTarget:self action:@selector(handleScroll:)],
    [[FBRoute POST:@"/wda/scroll"] respondWithTarget:self action:@selector(handleScroll:)],

    [[FBRoute POST:@"/wda/element/:uuid/scrollTo"] respondWithTarget:self action:@selector(handleScrollTo:)],

    [[FBRoute POST:@"/wda/element/:uuid/dragfromtoforduration"] respondWithTarget:self action:@selector(handleDrag:)],
    [[FBRoute POST:@"/wda/dragfromtoforduration"] respondWithTarget:self action:@selector(handleDrag:)],

    [[FBRoute POST:@"/wda/element/:uuid/pressAndDragWithVelocity"] respondWithTarget:self action:@selector(handlePressAndDragWithVelocity:)],
    [[FBRoute POST:@"/wda/pressAndDragWithVelocity"] respondWithTarget:self action:@selector(handlePressAndDragCoordinateWithVelocity:)],

    [[FBRoute POST:@"/wda/element/:uuid/forceTouch"] respondWithTarget:self action:@selector(handleForceTouch:)],
    [[FBRoute POST:@"/wda/forceTouch"] respondWithTarget:self action:@selector(handleForceTouch:)],

    [[FBRoute POST:@"/wda/element/:uuid/tap"] respondWithTarget:self action:@selector(handleTap:)],
    [[FBRoute POST:@"/wda/tap"] respondWithTarget:self action:@selector(handleTap:)],

    [[FBRoute POST:@"/wda/pickerwheel/:uuid/select"] respondWithTarget:self action:@selector(handleWheelSelect:)],
#endif
    [[FBRoute POST:@"/wda/keys"] respondWithTarget:self action:@selector(handleKeys:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetEnabled:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(@(element.isWDEnabled));
}

+ (id<FBResponsePayload>)handleGetRect:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(element.wdRect);
}

+ (id<FBResponsePayload>)handleGetAttribute:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  NSString *attributeName = request.parameters[@"name"];
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  id attributeValue = [element fb_valueForWDAttributeName:attributeName];
  return FBResponseWithObject(attributeValue ?: [NSNull null]);
}

+ (id<FBResponsePayload>)handleGetText:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  // https://github.com/appium/appium-xcuitest-driver/issues/2552
  id<FBXCElementSnapshot> snapshot = [element fb_customSnapshot];
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  id text = FBFirstNonEmptyValue(wrappedSnapshot.wdValue, wrappedSnapshot.wdLabel);
  return FBResponseWithObject(text ?: @"");
}

+ (id<FBResponsePayload>)handleGetDisplayed:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(@(element.isWDVisible));
}

+ (id<FBResponsePayload>)handleGetAccessible:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(@(element.isWDAccessible));
}

+ (id<FBResponsePayload>)handleGetIsAccessibilityContainer:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(@(element.isWDAccessibilityContainer));
}

+ (id<FBResponsePayload>)handleGetName:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(element.wdType);
}

+ (id<FBResponsePayload>)handleGetSelected:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  return FBResponseWithObject(@(element.wdSelected));
}

+ (id<FBResponsePayload>)handleSetValue:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]
                                       checkStaleness:YES];
  id value = request.arguments[@"value"] ?: request.arguments[@"text"];
  if (!value) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Neither 'value' nor 'text' parameter is provided" traceback:nil]);
  }
  NSString *textToType = [value isKindOfClass:NSArray.class]
    ? [value componentsJoinedByString:@""]
    : value;
  XCUIElementType elementType = [element elementType];
#if !TARGET_OS_TV
  if (elementType == XCUIElementTypePickerWheel) {
    [element adjustToPickerWheelValue:textToType];
    return FBResponseWithOK();
  }
#endif
  if (elementType == XCUIElementTypeSlider) {
    CGFloat sliderValue = textToType.floatValue;
    if (sliderValue < 0.0 || sliderValue > 1.0 ) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Value of slider should be in 0..1 range" traceback:nil]);
    }
    [element adjustToNormalizedSliderPosition:sliderValue];
    return FBResponseWithOK();
  }
  NSUInteger frequency = (NSUInteger)[request.arguments[@"frequency"] longLongValue] ?: [FBConfiguration maxTypingFrequency];
  NSError *error = nil;
  if (![element fb_typeText:textToType
                shouldClear:NO
                  frequency:frequency
                      error:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleClick:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"] checkStaleness:YES];
#if TARGET_OS_IOS
  [element tap];
#elif TARGET_OS_TV
  NSError *error = nil;
  if (![element fb_selectWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
  }
#endif
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleClear:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  NSError *error;
  if (![element fb_clearTextWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
  }
  return FBResponseWithOK();
}

#if TARGET_OS_TV
+ (id<FBResponsePayload>)handleGetFocused:(FBRouteRequest *)request
{
  // `BOOL isFocused = [elementCache elementForUUID:request.parameters[@"uuid"]];`
  // returns wrong true/false after moving focus by key up/down, for example.
  // Thus, ensure the focus compares the status with `fb_focusedElement`.
  BOOL isFocused = NO;
  XCUIElement *focusedElement = request.session.activeApplication.fb_focusedElement;
  if (focusedElement != nil) {
    FBElementCache *elementCache = request.session.elementCache;
    BOOL useNativeCachingStrategy = request.session.useNativeCachingStrategy;
    NSString *focusedUUID = [elementCache storeElement:(useNativeCachingStrategy
                                                        ? focusedElement
                                                        : [focusedElement fb_stableInstanceWithUid:focusedElement.fb_uid])];
    focusedElement.lastSnapshot = nil;
    if (focusedUUID && [focusedUUID isEqualToString:(id)request.parameters[@"uuid"]]) {
      isFocused = YES;
    }
  }

  return FBResponseWithObject(@(isFocused));
}

+ (id<FBResponsePayload>)handleFocuse:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  NSError *error;
  if (![element fb_setFocusWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
  }
  return FBResponseWithStatus([FBCommandStatus okWithValue: FBDictionaryResponseWithElement(element, FBConfiguration.shouldUseCompactResponses)]);
}
#else
+ (id<FBResponsePayload>)handleDoubleTap:(FBRouteRequest *)request
{
  NSError *error;
  id target = [self targetWithXyCoordinatesFromRequest:request error:&error];
  if (nil == target) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  [target doubleTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTwoFingerTap:(FBRouteRequest *)request
{
  XCUIElement *element = [self targetFromRequest:request];
  [element twoFingerTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTapWithNumberOfTaps:(FBRouteRequest *)request
{
  if (nil == request.arguments[@"numberOfTaps"] || nil == request.arguments[@"numberOfTouches"]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Both 'numberOfTaps' and 'numberOfTouches' arguments must be provided"
                                                                       traceback:nil]);
  }
  XCUIElement *element = [self targetFromRequest:request];
  [element tapWithNumberOfTaps:[request.arguments[@"numberOfTaps"] integerValue]
               numberOfTouches:[request.arguments[@"numberOfTouches"] integerValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTouchAndHold:(FBRouteRequest *)request
{
  NSError *error;
  id target = [self targetWithXyCoordinatesFromRequest:request error:&error];
  if (nil == target) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  [target pressForDuration:[request.arguments[@"duration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePressAndDragWithVelocity:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [self targetFromRequest:request];
  [element pressForDuration:[request.arguments[@"pressDuration"] doubleValue]
          thenDragToElement:[elementCache elementForUUID:(NSString *)request.arguments[@"toElement"] checkStaleness:YES]
               withVelocity:[request.arguments[@"velocity"] doubleValue]
        thenHoldForDuration:[request.arguments[@"holdDuration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePressAndDragCoordinateWithVelocity:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  CGVector startOffset = CGVectorMake((CGFloat)[request.arguments[@"fromX"] doubleValue],
                                     (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  XCUICoordinate *startCoordinate = [self.class gestureCoordinateWithOffset:startOffset
                                                                    element:session.activeApplication];
  CGVector endOffset = CGVectorMake((CGFloat)[request.arguments[@"toX"] doubleValue],
                                    (CGFloat)[request.arguments[@"toY"] doubleValue]);
  XCUICoordinate *endCoordinate = [self.class gestureCoordinateWithOffset:endOffset
                                                                  element:session.activeApplication];
  [startCoordinate pressForDuration:[request.arguments[@"pressDuration"] doubleValue]
               thenDragToCoordinate:endCoordinate
                       withVelocity:[request.arguments[@"velocity"] doubleValue]
                thenHoldForDuration:[request.arguments[@"holdDuration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleScroll:(FBRouteRequest *)request
{
  XCUIElement *element = [self targetFromRequest:request];
  // Using presence of arguments as a way to convey control flow seems like a pretty bad idea but it's
  // what ios-driver did and sadly, we must copy them.
  NSString *const name = request.arguments[@"name"];
  if (name) {
    XCUIElement *childElement = [[[[element.fb_query descendantsMatchingType:XCUIElementTypeAny]
                                   matchingIdentifier:name] allElementsBoundByIndex] lastObject];
    if (!childElement) {
      return FBResponseWithStatus([FBCommandStatus noSuchElementErrorWithMessage:[NSString stringWithFormat:@"'%@' identifier didn't match any elements", name]
                                                                       traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
    }
    return [self.class handleScrollElementToVisible:childElement withRequest:request];
  }

  NSString *const direction = request.arguments[@"direction"];
  if (direction) {
    NSString *const distanceString = request.arguments[@"distance"] ?: @"1.0";
    CGFloat distance = (CGFloat)distanceString.doubleValue;
    if ([direction isEqualToString:@"up"]) {
      [element fb_scrollUpByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"down"]) {
      [element fb_scrollDownByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"left"]) {
      [element fb_scrollLeftByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"right"]) {
      [element fb_scrollRightByNormalizedDistance:distance];
    }
    return FBResponseWithOK();
  }

  NSString *const predicateString = request.arguments[@"predicateString"];
  if (predicateString) {
    NSPredicate *formattedPredicate = [NSPredicate fb_snapshotBlockPredicateWithPredicate:[NSPredicate
                                                                                           predicateWithFormat:predicateString]];
    XCUIElement *childElement = [[[[element.fb_query descendantsMatchingType:XCUIElementTypeAny]
                                   matchingPredicate:formattedPredicate] allElementsBoundByIndex] lastObject];
    if (!childElement) {
      return FBResponseWithStatus([FBCommandStatus noSuchElementErrorWithMessage:[NSString stringWithFormat:@"'%@' predicate didn't match any elements", predicateString]
                                                                       traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
    }
    return [self.class handleScrollElementToVisible:childElement withRequest:request];
  }

  if (request.arguments[@"toVisible"]) {
    return [self.class handleScrollElementToVisible:element withRequest:request];
  }
  return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Unsupported scroll type" traceback:nil]);
}

+ (id<FBResponsePayload>)handleScrollTo:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]];
  NSError *error;
  return [element fb_nativeScrollToVisibleWithError:&error]
    ? FBResponseWithOK()
    : FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description
                                                                      traceback:nil]);
}

+ (id<FBResponsePayload>)handleDrag:(FBRouteRequest *)request
{
  XCUIElement *target = [self targetFromRequest:request];
  CGVector startOffset = CGVectorMake([request.arguments[@"fromX"] doubleValue],
                                      [request.arguments[@"fromY"] doubleValue]);
  XCUICoordinate *startCoordinate = [self.class gestureCoordinateWithOffset:startOffset element:target];
  CGVector endOffset = CGVectorMake([request.arguments[@"toX"] doubleValue],
                                    [request.arguments[@"toY"] doubleValue]);
  XCUICoordinate *endCoordinate = [self.class gestureCoordinateWithOffset:endOffset element:target];
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  [startCoordinate pressForDuration:duration thenDragToCoordinate:endCoordinate];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSwipe:(FBRouteRequest *)request
{
  NSString *const direction = request.arguments[@"direction"];
  if (!direction) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Missing 'direction' parameter" traceback:nil]);
  }
  NSArray<NSString *> *supportedDirections = @[@"up", @"down", @"left", @"right"];
  if (![supportedDirections containsObject:direction.lowercaseString]) {
    NSString *message = [NSString stringWithFormat:@"Unsupported swipe direction '%@'. Only the following directions are supported: %@", direction, supportedDirections];
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:message
                                                                       traceback:nil]);
  }
  NSError *error;
  id target = [self targetWithXyCoordinatesFromRequest:request error:&error];
  if (nil == target) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  [target fb_swipeWithDirection:direction velocity:request.arguments[@"velocity"]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTap:(FBRouteRequest *)request
{
  NSError *error;
  id target = [self targetWithXyCoordinatesFromRequest:request error:&error];
  if (nil == target) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  [target tap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePinch:(FBRouteRequest *)request
{
  XCUIElement *element = [self targetFromRequest:request];
  CGFloat scale = (CGFloat)[request.arguments[@"scale"] doubleValue];
  CGFloat velocity = (CGFloat)[request.arguments[@"velocity"] doubleValue];
  [element pinchWithScale:scale velocity:velocity];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleRotate:(FBRouteRequest *)request
{
  XCUIElement *element = [self targetFromRequest:request];
  CGFloat rotation = (CGFloat)[request.arguments[@"rotation"] doubleValue];
  CGFloat velocity = (CGFloat)[request.arguments[@"velocity"] doubleValue];
  [element rotate:rotation withVelocity:velocity];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleForceTouch:(FBRouteRequest *)request
{
  XCUIElement *element = [self targetFromRequest:request];
  NSNumber *pressure = request.arguments[@"pressure"];
  NSNumber *duration = request.arguments[@"duration"];
  NSNumber *x = request.arguments[@"x"];
  NSNumber *y = request.arguments[@"y"];
  NSValue *hitPoint = (nil == x || nil == y)
    ? nil
    : [NSValue valueWithCGPoint:CGPointMake((CGFloat)[x doubleValue], (CGFloat)[y doubleValue])];
  NSError *error;
  BOOL didSucceed = [element fb_forceTouchCoordinate:hitPoint
                                            pressure:pressure
                                            duration:duration
                                               error:&error];
  return didSucceed
    ? FBResponseWithOK()
    : FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description
                                                                    traceback:nil]);
}
#endif

+ (id<FBResponsePayload>)handleKeys:(FBRouteRequest *)request
{
  NSString *textToType = [request.arguments[@"value"] componentsJoinedByString:@""];
  NSUInteger frequency = [request.arguments[@"frequency"] unsignedIntegerValue] ?: [FBConfiguration maxTypingFrequency];
  NSError *error;
  if (!FBTypeText(textToType, frequency, &error)) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description
                                                                           traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetWindowSize:(FBRouteRequest *)request
{
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;

  CGRect frame = app.wdFrame;
#if TARGET_OS_TV
  CGSize screenSize = frame.size;
#else
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, app.interfaceOrientation);
#endif
  return FBResponseWithObject(@{
    @"width": @(screenSize.width),
    @"height": @(screenSize.height),
  });
}


+ (id<FBResponsePayload>)handleGetWindowRect:(FBRouteRequest *)request
{
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;

  CGRect frame = app.wdFrame;
#if TARGET_OS_TV
  CGSize screenSize = frame.size;
#else
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, app.interfaceOrientation);
#endif
  return FBResponseWithObject(@{
    @"x": @(frame.origin.x),
    @"y": @(frame.origin.y),
    @"width": @(screenSize.width),
    @"height": @(screenSize.height),
  });
}

+ (id<FBResponsePayload>)handleElementScreenshot:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]
                                       checkStaleness:YES];
  NSData *screenshotData = [element.screenshot PNGRepresentation];
  if (nil == screenshotData) {
    NSString *errMsg = [NSString stringWithFormat:@"Cannot take a screenshot of %@", element.description];
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:errMsg
                                                                             traceback:nil]);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:0];
  return FBResponseWithObject(screenshot);
}


#if !TARGET_OS_TV
static const CGFloat DEFAULT_PICKER_OFFSET = (CGFloat)0.2;
static const NSInteger DEFAULT_MAX_PICKER_ATTEMPTS = 25;


+ (id<FBResponsePayload>)handleWheelSelect:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:(NSString *)request.parameters[@"uuid"]
                                       checkStaleness:YES];
  if ([element elementType] != XCUIElementTypePickerWheel) {
    NSString *errMsg = [NSString stringWithFormat:@"The element is expected to be a valid Picker Wheel control. '%@' was given instead", element.wdType];
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:errMsg
                                                                       traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
  }
  NSString* order = [request.arguments[@"order"] lowercaseString];
  CGFloat offset = DEFAULT_PICKER_OFFSET;
  if (request.arguments[@"offset"]) {
    offset = (CGFloat)[request.arguments[@"offset"] doubleValue];
    if (offset <= 0.0 || offset > 0.5) {
      NSString *errMsg = [NSString stringWithFormat:@"'offset' value is expected to be in range (0.0, 0.5]. '%@' was given instead", request.arguments[@"offset"]];
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:errMsg
                                                                         traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
    }
  }
  NSNumber *maxAttempts = request.arguments[@"maxAttempts"] ?: @(DEFAULT_MAX_PICKER_ATTEMPTS);
  NSString *expectedValue = request.arguments[@"value"];
  NSInteger attempt = 0;
  while (attempt < [maxAttempts integerValue]) {
    BOOL isSuccessful = false;
    NSError *error;
    if ([order isEqualToString:@"next"]) {
      isSuccessful = [element fb_selectNextOptionWithOffset:offset error:&error];
    } else if ([order isEqualToString:@"previous"]) {
      isSuccessful = [element fb_selectPreviousOptionWithOffset:offset error:&error];
    } else {
      NSString *errMsg = [NSString stringWithFormat:@"Only 'previous' and 'next' order values are supported. '%@' was given instead", request.arguments[@"order"]];
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:errMsg
                                                                         traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
    }
    if (!isSuccessful) {
      return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
    }
    if (nil == expectedValue || [element.wdValue isEqualToString:expectedValue]) {
      return FBResponseWithOK();
    }
    attempt++;
  }
  NSString *errMsg = [NSString stringWithFormat:@"Cannot select the expected picker wheel value '%@' after %ld attempts", expectedValue, attempt];
  return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:errMsg traceback:nil]);
}

#pragma mark - Helpers

+ (id<FBResponsePayload>)handleScrollElementToVisible:(XCUIElement *)element withRequest:(FBRouteRequest *)request
{
  NSError *error;
  if (!element.exists) {
    return FBResponseWithStatus([FBCommandStatus elementNotVisibleErrorWithMessage:@"Can't scroll to element that does not exist" traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
  }
  if (![element fb_scrollToVisibleWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description
                                                                           traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
  }
  return FBResponseWithOK();
}

/**
 Returns gesture coordinate for the element based on absolute coordinate

 @param offset absolute screen offset for the given application
 @param element the element instance to perform the gesture on
 @return translated gesture coordinates ready to be passed to XCUICoordinate methods
 */
+ (XCUICoordinate *)gestureCoordinateWithOffset:(CGVector)offset
                                        element:(XCUIElement *)element
{
  return [[element coordinateWithNormalizedOffset:CGVectorMake(0, 0)] coordinateWithOffset:offset];
}

/**
 Returns either coordinates or the target element for the given request that expects 'x' and 'y' coordannates

 @param request HTTP request object
 @param error Error instance if any
 @return Either XCUICoordinate or XCUIElement instance. nil if the input data is invalid
 */
+ (nullable id)targetWithXyCoordinatesFromRequest:(FBRouteRequest *)request error:(NSError **)error
{
  NSNumber *x = request.arguments[@"x"];
  NSNumber *y = request.arguments[@"y"];
  if (nil == x && nil == y) {
    return [self targetFromRequest:request];
  }
  if ((nil == x && nil != y) || (nil != x && nil == y)) {
    [[[FBErrorBuilder alloc]
      withDescription:@"Both x and y coordinates must be provided"]
     buildError:error];
    return nil;
  }
  return [self gestureCoordinateWithOffset:CGVectorMake(x.doubleValue, y.doubleValue)
                                   element:[self targetFromRequest:request]];
}

/**
 Returns the target element for the given request

 @param request HTTP request object
 @return Matching XCUIElement instance
 */
+ (XCUIElement *)targetFromRequest:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  NSString *elementUuid = (NSString *)request.parameters[@"uuid"];
  return nil == elementUuid
    ? request.session.activeApplication
    : [elementCache elementForUUID:elementUuid checkStaleness:YES];
}

#endif

@end
