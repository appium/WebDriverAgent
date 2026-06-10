/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScreenCaptureCommands.h"

#import "FBConfiguration.h"
#import "FBRouteRequest.h"
#import "FBVideoStreamManager.h"

static const NSUInteger DEFAULT_CAPTURE_FPS = 30;
static const NSUInteger DEFAULT_CAPTURE_BITRATE = 6000000;

@implementation FBScreenCaptureCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/mobilerun/screencapture/start"] respondWithTarget:self action:@selector(handleStartScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/stop"] respondWithTarget:self action:@selector(handleStopAllScreenCapture:)],
    [[FBRoute GET:@"/mobilerun/screencapture"] respondWithTarget:self action:@selector(handleListScreenCapture:)],
    [[FBRoute GET:@"/mobilerun/screencapture/:id"] respondWithTarget:self action:@selector(handleGetScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/:id/stop"] respondWithTarget:self action:@selector(handleStopScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/:id/keyframe"] respondWithTarget:self action:@selector(handleRequestKeyFrame:)],

    [[FBRoute POST:@"/mobilerun/screencapture/start"].withoutSession respondWithTarget:self action:@selector(handleStartScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/stop"].withoutSession respondWithTarget:self action:@selector(handleStopAllScreenCapture:)],
    [[FBRoute GET:@"/mobilerun/screencapture"].withoutSession respondWithTarget:self action:@selector(handleListScreenCapture:)],
    [[FBRoute GET:@"/mobilerun/screencapture/:id"].withoutSession respondWithTarget:self action:@selector(handleGetScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/:id/stop"].withoutSession respondWithTarget:self action:@selector(handleStopScreenCapture:)],
    [[FBRoute POST:@"/mobilerun/screencapture/:id/keyframe"].withoutSession respondWithTarget:self action:@selector(handleRequestKeyFrame:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handleStartScreenCapture:(FBRouteRequest *)request
{
  FBVideoCodec codec;
  NSString *codecError = nil;
  if (![self codecFromArguments:request.arguments codec:&codec errorMessage:&codecError]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:codecError traceback:nil]);
  }

  FBVideoFraming framing;
  NSString *framingError = nil;
  if (![self framingFromArguments:request.arguments framing:&framing errorMessage:&framingError]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:framingError traceback:nil]);
  }

  NSInteger width = [request.arguments[@"width"] integerValue];
  NSInteger height = [request.arguments[@"height"] integerValue];
  if (width <= 0 || height <= 0) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Both 'width' and 'height' must be provided as positive integers" traceback:nil]);
  }

  FBScreenCaptureConfiguration *configuration = [[FBScreenCaptureConfiguration alloc] init];
  configuration.codec = codec;
  configuration.framing = framing;
  // Most hardware encoders require even dimensions.
  configuration.width = (NSUInteger)(width - (width % 2));
  configuration.height = (NSUInteger)(height - (height % 2));
  NSNumber *bitrate = request.arguments[@"bitrate"];
  configuration.bitrate = (nil != bitrate && bitrate.integerValue > 0) ? bitrate.unsignedIntegerValue : DEFAULT_CAPTURE_BITRATE;
  NSNumber *fps = request.arguments[@"fps"];
  configuration.fps = (nil != fps && fps.integerValue > 0) ? fps.unsignedIntegerValue : DEFAULT_CAPTURE_FPS;
  NSNumber *port = request.arguments[@"port"];
  if (nil != port) {
    NSInteger portValue = port.integerValue;
    // 0 asks the manager to auto-assign the next free port; anything outside the TCP port range
    // would silently wrap when cast to uint16_t, so reject it explicitly.
    if (portValue < 0 || portValue > UINT16_MAX) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'port' must be an integer in the range 0..65535 (0 auto-assigns the next free port)" traceback:nil]);
    }
    configuration.port = (uint16_t)portValue;
  }

  NSError *error;
  FBVideoStreamSession *session = [FBVideoStreamManager.sharedInstance startSessionWithConfiguration:configuration
                                                                                              error:&error];
  if (nil == session) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithObject(session.toDictionary);
}

+ (id<FBResponsePayload>)handleListScreenCapture:(FBRouteRequest *)request
{
  return FBResponseWithObject(@{@"sessions": [FBVideoStreamManager.sharedInstance activeSessionsInfo]});
}

+ (id<FBResponsePayload>)handleGetScreenCapture:(FBRouteRequest *)request
{
  NSNumber *identifier = [self identifierFromRequest:request];
  if (nil == identifier) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The screen capture session id must be a positive integer" traceback:nil]);
  }
  FBVideoStreamSession *session = [FBVideoStreamManager.sharedInstance sessionWithIdentifier:identifier.unsignedIntegerValue];
  return FBResponseWithObject(session ? session.toDictionary : [NSNull null]);
}

+ (id<FBResponsePayload>)handleStopScreenCapture:(FBRouteRequest *)request
{
  NSNumber *identifier = [self identifierFromRequest:request];
  if (nil == identifier) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The screen capture session id must be a positive integer" traceback:nil]);
  }
  if (![FBVideoStreamManager.sharedInstance stopSessionWithIdentifier:identifier.unsignedIntegerValue]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"There is no screen capture session with id %@", identifier] traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleStopAllScreenCapture:(FBRouteRequest *)request
{
  [FBVideoStreamManager.sharedInstance stopAllSessions];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleRequestKeyFrame:(FBRouteRequest *)request
{
  NSNumber *identifier = [self identifierFromRequest:request];
  if (nil == identifier) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The screen capture session id must be a positive integer" traceback:nil]);
  }
  if (![FBVideoStreamManager.sharedInstance requestKeyFrameForSessionWithIdentifier:identifier.unsignedIntegerValue]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"There is no screen capture session with id %@", identifier] traceback:nil]);
  }
  return FBResponseWithOK();
}

#pragma mark - Helpers

+ (nullable NSNumber *)identifierFromRequest:(FBRouteRequest *)request
{
  NSString *rawId = request.parameters[@"id"];
  if (nil == rawId || rawId.length == 0) {
    return nil;
  }
  NSScanner *scanner = [NSScanner scannerWithString:rawId];
  long long value = 0;
  if (![scanner scanLongLong:&value] || !scanner.isAtEnd || value <= 0) {
    return nil;
  }
  return @((NSUInteger)value);
}

+ (BOOL)codecFromArguments:(NSDictionary *)arguments
                     codec:(FBVideoCodec *)codec
              errorMessage:(NSString **)errorMessage
{
  id codecValue = arguments[@"codec"];
  if (nil == codecValue) {
    *codec = FBVideoCodecH264;
    return YES;
  }
  if (![codecValue isKindOfClass:[NSString class]]) {
    if (errorMessage) {
      *errorMessage = @"'codec' must be a string ('h264' or 'h265')";
    }
    return NO;
  }
  NSString *codecName = (NSString *)codecValue;
  if (codecName.length == 0) {
    *codec = FBVideoCodecH264;
    return YES;
  }
  NSString *normalized = codecName.lowercaseString;
  if ([normalized isEqualToString:@"h264"] || [normalized isEqualToString:@"avc"]) {
    *codec = FBVideoCodecH264;
    return YES;
  }
  if ([normalized isEqualToString:@"h265"] || [normalized isEqualToString:@"hevc"]) {
    *codec = FBVideoCodecH265;
    return YES;
  }
  if (errorMessage) {
    *errorMessage = [NSString stringWithFormat:@"Unsupported codec '%@'. Supported values are 'h264' and 'h265'", codecName];
  }
  return NO;
}

+ (BOOL)framingFromArguments:(NSDictionary *)arguments
                     framing:(FBVideoFraming *)framing
                errorMessage:(NSString **)errorMessage
{
  id framingValue = arguments[@"framing"];
  if (nil == framingValue) {
    *framing = FBVideoFramingAnnexB;
    return YES;
  }
  if (![framingValue isKindOfClass:[NSString class]]) {
    if (errorMessage) {
      *errorMessage = @"'framing' must be a string ('annexb' or 'scrcpy')";
    }
    return NO;
  }
  NSString *framingName = (NSString *)framingValue;
  if (framingName.length == 0) {
    *framing = FBVideoFramingAnnexB;
    return YES;
  }
  NSString *normalized = framingName.lowercaseString;
  if ([normalized isEqualToString:@"annexb"] || [normalized isEqualToString:@"annex-b"] || [normalized isEqualToString:@"raw"]) {
    *framing = FBVideoFramingAnnexB;
    return YES;
  }
  if ([normalized isEqualToString:@"scrcpy"] || [normalized isEqualToString:@"packet"] || [normalized isEqualToString:@"packetized"]) {
    *framing = FBVideoFramingScrcpy;
    return YES;
  }
  if (errorMessage) {
    *errorMessage = [NSString stringWithFormat:@"Unsupported framing '%@'. Supported values are 'annexb' and 'scrcpy'", framingName];
  }
  return NO;
}

@end
