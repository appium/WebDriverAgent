/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */


#import "XCUIApplication+FBTouchAction.h"

#import "FBAppiumActionsSynthesizer.h"
#import "FBBaseActionsSynthesizer.h"
#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBRunLoopSpinner.h"
#import "FBW3CActionsSynthesizer.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCEventGenerator.h"
#import "XCUIElement+FBUtilities.h"

#if !TARGET_OS_TV

@implementation XCUIApplication (FBTouchAction)

+ (BOOL)handleEventSynthesWithError:(NSError *)error
{
  if ([error.localizedDescription containsString:@"not visible"]) {
    [[NSException exceptionWithName:FBElementNotVisibleException
                             reason:error.localizedDescription
                           userInfo:error.userInfo] raise];
  }
  return NO;
}

- (BOOL)fb_performActionsWithSynthesizerType:(Class)synthesizerType
                                     actions:(NSArray *)actions
                                elementCache:(FBElementCache *)elementCache
                                       error:(NSError **)error
{
  FBBaseActionsSynthesizer *synthesizer = [[synthesizerType alloc] initWithActions:actions
                                                                    forApplication:self
                                                                      elementCache:elementCache
                                                                             error:error];
  if (nil == synthesizer) {
    return NO;
  }
  XCSynthesizedEventRecord *eventRecord = [synthesizer synthesizeWithError:error];
  if (nil == eventRecord) {
    return [self.class handleEventSynthesWithError:*error];
  }
  return [self fb_synthesizeEvent:eventRecord error:error];
}

- (BOOL)fb_performAppiumTouchActions:(NSArray *)actions
                        elementCache:(FBElementCache *)elementCache
                               error:(NSError **)error
{
  if (![self fb_performActionsWithSynthesizerType:FBAppiumActionsSynthesizer.class
                                          actions:actions
                                     elementCache:elementCache
                                            error:error]) {
    return NO;
  }
  [self fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  return YES;
}

- (BOOL)fb_performW3CActions:(NSArray *)actions
                elementCache:(FBElementCache *)elementCache
                       error:(NSError **)error
{
  if (![self fb_performActionsWithSynthesizerType:FBW3CActionsSynthesizer.class
                                          actions:actions
                                     elementCache:elementCache
                                            error:error]) {
    return NO;
  }
  [self fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  return YES;
}

- (BOOL)fb_synthesizeEvent:(XCSynthesizedEventRecord *)event error:(NSError *__autoreleasing*)error
{
  return [FBXCTestDaemonsProxy synthesizeEventWithRecord:event error:error];
}

@end
#endif
