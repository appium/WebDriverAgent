/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAudioCaptureCommands.h"

#import "FBAudioStreamManager.h"
#import "FBRouteRequest.h"

static const NSUInteger DEFAULT_AUDIO_BITRATE = 128000;
static const NSUInteger DEFAULT_AUDIO_CHANNELS = 2;

@implementation FBAudioCaptureCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/mobilerun/audiocapture/start"] respondWithTarget:self action:@selector(handleStartAudioCapture:)],
    [[FBRoute POST:@"/mobilerun/audiocapture/stop"] respondWithTarget:self action:@selector(handleStopAllAudioCapture:)],
    [[FBRoute GET:@"/mobilerun/audiocapture"] respondWithTarget:self action:@selector(handleListAudioCapture:)],
    [[FBRoute GET:@"/mobilerun/audiocapture/:id"] respondWithTarget:self action:@selector(handleGetAudioCapture:)],
    [[FBRoute POST:@"/mobilerun/audiocapture/:id/stop"] respondWithTarget:self action:@selector(handleStopAudioCapture:)],

    [[FBRoute POST:@"/mobilerun/audiocapture/start"].withoutSession respondWithTarget:self action:@selector(handleStartAudioCapture:)],
    [[FBRoute POST:@"/mobilerun/audiocapture/stop"].withoutSession respondWithTarget:self action:@selector(handleStopAllAudioCapture:)],
    [[FBRoute GET:@"/mobilerun/audiocapture"].withoutSession respondWithTarget:self action:@selector(handleListAudioCapture:)],
    [[FBRoute GET:@"/mobilerun/audiocapture/:id"].withoutSession respondWithTarget:self action:@selector(handleGetAudioCapture:)],
    [[FBRoute POST:@"/mobilerun/audiocapture/:id/stop"].withoutSession respondWithTarget:self action:@selector(handleStopAudioCapture:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handleStartAudioCapture:(FBRouteRequest *)request
{
  // Future-proofing: only Opus exists today, but reject unknown codecs explicitly.
  id codecValue = request.arguments[@"codec"];
  if (nil != codecValue &&
      (![codecValue isKindOfClass:NSString.class] ||
       ([(NSString *)codecValue length] > 0 && ![[(NSString *)codecValue lowercaseString] isEqualToString:@"opus"]))) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Unsupported codec. The only supported value is 'opus'" traceback:nil]);
  }

  FBAudioFraming framing;
  NSString *framingError = nil;
  if (![self framingFromArguments:request.arguments framing:&framing errorMessage:&framingError]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:framingError traceback:nil]);
  }

  FBAudioCaptureConfiguration *configuration = [[FBAudioCaptureConfiguration alloc] init];
  configuration.framing = framing;
  NSNumber *bitrate = request.arguments[@"bitrate"];
  configuration.bitrate = (nil != bitrate && bitrate.integerValue > 0) ? bitrate.unsignedIntegerValue : DEFAULT_AUDIO_BITRATE;
  NSNumber *channels = request.arguments[@"channels"];
  if (nil == channels) {
    configuration.channels = DEFAULT_AUDIO_CHANNELS;
  } else if (channels.integerValue != 1 && channels.integerValue != 2) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"'channels' must be 1 or 2" traceback:nil]);
  } else {
    configuration.channels = channels.unsignedIntegerValue;
  }
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
  FBAudioStreamSession *session = [FBAudioStreamManager.sharedInstance startSessionWithConfiguration:configuration
                                                                                               error:&error];
  if (nil == session) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithObject(session.toDictionary);
}

+ (id<FBResponsePayload>)handleListAudioCapture:(FBRouteRequest *)request
{
  return FBResponseWithObject(@{@"sessions": [FBAudioStreamManager.sharedInstance activeSessionsInfo]});
}

+ (id<FBResponsePayload>)handleGetAudioCapture:(FBRouteRequest *)request
{
  NSNumber *identifier = [self identifierFromRequest:request];
  if (nil == identifier) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The audio capture session id must be a positive integer" traceback:nil]);
  }
  FBAudioStreamSession *session = [FBAudioStreamManager.sharedInstance sessionWithIdentifier:identifier.unsignedIntegerValue];
  return FBResponseWithObject(session ? session.toDictionary : [NSNull null]);
}

+ (id<FBResponsePayload>)handleStopAudioCapture:(FBRouteRequest *)request
{
  NSNumber *identifier = [self identifierFromRequest:request];
  if (nil == identifier) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The audio capture session id must be a positive integer" traceback:nil]);
  }
  if (![FBAudioStreamManager.sharedInstance stopSessionWithIdentifier:identifier.unsignedIntegerValue]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"There is no audio capture session with id %@", identifier] traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleStopAllAudioCapture:(FBRouteRequest *)request
{
  [FBAudioStreamManager.sharedInstance stopAllSessions];
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

+ (BOOL)framingFromArguments:(NSDictionary *)arguments
                     framing:(FBAudioFraming *)framing
                errorMessage:(NSString **)errorMessage
{
  id framingValue = arguments[@"framing"];
  if (nil == framingValue) {
    *framing = FBAudioFramingRaw;
    return YES;
  }
  if (![framingValue isKindOfClass:[NSString class]]) {
    if (errorMessage) {
      *errorMessage = @"'framing' must be a string ('raw' or 'scrcpy')";
    }
    return NO;
  }
  NSString *framingName = (NSString *)framingValue;
  if (framingName.length == 0) {
    *framing = FBAudioFramingRaw;
    return YES;
  }
  NSString *normalized = framingName.lowercaseString;
  if ([normalized isEqualToString:@"raw"] || [normalized isEqualToString:@"bare"]) {
    *framing = FBAudioFramingRaw;
    return YES;
  }
  if ([normalized isEqualToString:@"scrcpy"] || [normalized isEqualToString:@"packet"] || [normalized isEqualToString:@"packetized"]) {
    *framing = FBAudioFramingScrcpy;
    return YES;
  }
  if (errorMessage) {
    *errorMessage = [NSString stringWithFormat:@"Unsupported framing '%@'. Supported values are 'raw' and 'scrcpy'", framingName];
  }
  return NO;
}

@end
