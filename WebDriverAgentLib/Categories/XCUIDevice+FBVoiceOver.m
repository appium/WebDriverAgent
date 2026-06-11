/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIDevice+FBVoiceOver.h"

#import "FBErrorBuilder.h"

static NSString *const FBVoiceOverSDKUnsupportedError =
@"The current OS runtime does not support VoiceOver control. This API requires an iOS 27+ runtime";

static BOOL FBVoiceOverBuildSDKUnsupportedError(NSError **error)
{
  return [[[FBErrorBuilder builder]
           withDescription:FBVoiceOverSDKUnsupportedError]
          buildError:error];
}

static BOOL FBIsVoiceOverServiceAvailable(void)
{
  static BOOL isAvailable = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    isAvailable = [XCUIDevice.sharedDevice respondsToSelector:NSSelectorFromString(@"voiceOverService")];
  });
  return isAvailable;
}

static id FBVoiceOverService(NSError **error)
{
  if (!FBIsVoiceOverServiceAvailable()) {
    FBVoiceOverBuildSDKUnsupportedError(error);
    return nil;
  }
  return [XCUIDevice.sharedDevice valueForKey:@"voiceOverService"];
}

static BOOL FBInvokeVoiceOverBoolMethod(id voiceOverService,
                                        SEL selector,
                                        NSError **error)
{
  if (![voiceOverService respondsToSelector:selector]) {
    return FBVoiceOverBuildSDKUnsupportedError(error);
  }

  NSMethodSignature *signature = [voiceOverService methodSignatureForSelector:selector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
  [invocation setSelector:selector];
  [invocation setTarget:voiceOverService];
  NSError *invokeError = nil;
  [invocation setArgument:&invokeError atIndex:2];
  [invocation invoke];
  if (nil != invokeError) {
    if (error) {
      *error = invokeError;
    }
    return NO;
  }

  BOOL result = NO;
  [invocation getReturnValue:&result];
  return result;
}

static id FBInvokeVoiceOverOutputMethod(id voiceOverService,
                                        SEL selector,
                                        NSError **error)
{
  if (![voiceOverService respondsToSelector:selector]) {
    FBVoiceOverBuildSDKUnsupportedError(error);
    return nil;
  }

  NSMethodSignature *signature = [voiceOverService methodSignatureForSelector:selector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
  [invocation setSelector:selector];
  [invocation setTarget:voiceOverService];
  NSError *invokeError = nil;
  [invocation setArgument:&invokeError atIndex:2];
  [invocation invoke];
  if (nil != invokeError) {
    if (error) {
      *error = invokeError;
    }
    return nil;
  }

  id __unsafe_unretained output = nil;
  [invocation getReturnValue:&output];
  return output;
}

static NSString *FBUtteranceFromVoiceOverOutput(id output, NSError **error)
{
  if (nil == output) {
    return nil;
  }

  if (![output respondsToSelector:NSSelectorFromString(@"utterance")]) {
    [[[FBErrorBuilder builder]
      withDescription:@"VoiceOver output does not provide an utterance"]
     buildError:error];
    return nil;
  }

  id utterance = [output valueForKey:@"utterance"];
  return [utterance isKindOfClass:NSString.class] ? utterance : nil;
}

static NSString *FBVoiceOverSpeechFromSelector(SEL selector, NSError **error)
{
  id service = FBVoiceOverService(error);
  if (nil == service) {
    return nil;
  }

  id output = FBInvokeVoiceOverOutputMethod(service, selector, error);
  if (nil != error && nil != *error) {
    return nil;
  }
  return FBUtteranceFromVoiceOverOutput(output, error);
}

static NSDictionary<NSString *, NSString *> *FBVoiceOverMoveSelectors(void)
{
  static NSDictionary<NSString *, NSString *> *selectors = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableDictionary<NSString *, NSString *> *mapping = [@{
      @"forward": @"moveForwardAndReturnError:",
      @"backward": @"moveBackwardAndReturnError:",
    } mutableCopy];
#if TARGET_OS_IOS
    mapping[@"in"] = @"moveInAndReturnError:";
    mapping[@"out"] = @"moveOutAndReturnError:";
#endif
    selectors = mapping.copy;
  });
  return selectors;
}

@implementation XCUIDevice (FBVoiceOver)

- (BOOL)fb_isVoiceOverServiceAvailable
{
  return FBIsVoiceOverServiceAvailable();
}

- (BOOL)fb_enableVoiceOver:(NSError **)error
{
  id service = FBVoiceOverService(error);
  if (nil == service) {
    return NO;
  }
  return FBInvokeVoiceOverBoolMethod(service,
                                     NSSelectorFromString(@"enableAndReturnError:"),
                                     error);
}

- (BOOL)fb_disableVoiceOver:(NSError **)error
{
  id service = FBVoiceOverService(error);
  if (nil == service) {
    return NO;
  }
  return FBInvokeVoiceOverBoolMethod(service,
                                     NSSelectorFromString(@"disableAndReturnError:"),
                                     error);
}

- (BOOL)fb_isVoiceOverEnabled:(NSError **)error
{
  id service = FBVoiceOverService(error);
  if (nil == service) {
    return NO;
  }

  if (![service respondsToSelector:NSSelectorFromString(@"isEnabled")] &&
      ![service respondsToSelector:NSSelectorFromString(@"enabled")]) {
    return FBVoiceOverBuildSDKUnsupportedError(error);
  }

  return [[service valueForKey:@"enabled"] boolValue];
}

- (nullable NSString *)fb_voiceOverMove:(NSString *)direction error:(NSError **)error
{
  if (![direction isKindOfClass:NSString.class] || 0 == direction.length) {
    return [[[FBErrorBuilder builder]
             withDescription:@"VoiceOver move direction must be a non-empty string"]
            buildError:error], nil;
  }

  NSString *normalizedDirection = direction.lowercaseString;
  NSString *selectorName = FBVoiceOverMoveSelectors()[normalizedDirection];
  if (nil == selectorName) {
    NSArray *supportedDirections = [FBVoiceOverMoveSelectors().allKeys sortedArrayUsingSelector:@selector(compare:)];
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Unsupported VoiceOver move direction '%@'. Supported directions: %@",
             direction, supportedDirections]
            buildError:error], nil;
  }

  return FBVoiceOverSpeechFromSelector(NSSelectorFromString(selectorName), error);
}

- (nullable NSString *)fb_voiceOverCurrentSpeech:(NSError **)error
{
  return FBVoiceOverSpeechFromSelector(NSSelectorFromString(@"currentSpeechAndReturnError:"), error);
}

@end
