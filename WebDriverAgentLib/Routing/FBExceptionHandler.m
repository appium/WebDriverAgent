/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBExceptionHandler.h"

#import "RouteResponse.h"

#import "FBResponsePayload.h"
#import "FBExceptions.h"

@implementation FBExceptionHandler

- (void)handleException:(NSException *)exception forResponse:(RouteResponse *)response
{
  FBCommandStatus *commandStatus;
  NSString *traceback = [NSString stringWithFormat:@"%@", exception.callStackSymbols];
  if ([exception.name isEqualToString:FBSessionDoesNotExistException]) {
    commandStatus = [FBCommandStatus noSuchDriverErrorWithMessage:exception.reason
                                                        traceback:traceback];
  } else if ([exception.name isEqualToString:FBInvalidArgumentException]
             || [exception.name isEqualToString:FBElementAttributeUnknownException]) {
    commandStatus = [FBCommandStatus invalidArgumentErrorWithMessage:exception.reason
                                                           traceback:traceback];
  } else if ([exception.name isEqualToString:FBApplicationCrashedException]
             || [exception.name isEqualToString:FBApplicationDeadlockDetectedException]) {
    commandStatus = [FBCommandStatus invalidElementStateErrorWithMessage:exception.reason
                                                               traceback:traceback];
  } else if ([exception.name isEqualToString:FBInvalidXPathException]
             || [exception.name isEqualToString:FBClassChainQueryParseException]) {
    commandStatus = [FBCommandStatus invalidSelectorErrorWithMessage:exception.reason
                                                           traceback:traceback];
  } else if ([exception.name isEqualToString:FBElementNotVisibleException]) {
    commandStatus = [FBCommandStatus elementNotVisibleErrorWithMessage:exception.reason
                                                             traceback:traceback];
  } else if ([exception.name isEqualToString:FBStaleElementException]) {
    commandStatus = [FBCommandStatus staleElementReferenceErrorWithMessage:exception.reason
                                                                 traceback:traceback];
  } else if ([exception.name isEqualToString:FBTimeoutException]) {
    commandStatus = [FBCommandStatus timeoutErrorWithMessage:exception.reason
                                                   traceback:traceback];
  } else {
    commandStatus = [FBCommandStatus unknownErrorWithMessage:exception.reason
                                                   traceback:traceback];
  }
  id<FBResponsePayload> payload = FBResponseWithStatus(commandStatus);
  [payload dispatchWithResponse:response];
}

@end
