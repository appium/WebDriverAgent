/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBExceptionHandler.h"

#import <RoutingHTTPServer/RouteResponse.h>

#import "FBAlert.h"
#import "FBResponsePayload.h"
#import "FBSession.h"
#import "XCUIElement+FBClassChain.h"
#import "FBXPath.h"


NSString *const FBInvalidArgumentException = @"FBInvalidArgumentException";
NSString *const FBSessionDoesNotExistException = @"FBSessionDoesNotExistException";
NSString *const FBApplicationDeadlockDetectedException = @"FBApplicationDeadlockDetectedException";
NSString *const FBElementAttributeUnknownException = @"FBElementAttributeUnknownException";
NSString *const FBElementNotVisibleException = @"FBElementNotVisibleException";

@implementation FBExceptionHandler

- (BOOL)webServer:(FBWebServer *)webServer handleException:(NSException *)exception forResponse:(RouteResponse *)response
{
  static NSDictionary<NSString *, NSArray *> *exceptionsMapping;
  static dispatch_once_t onceExceptionsMapping;
  dispatch_once(&onceExceptionsMapping, ^{
    exceptionsMapping = @{
      FBApplicationDeadlockDetectedException: @[@(FBCommandStatusApplicationDeadlockDetected)],
      FBSessionDoesNotExistException: @[@(FBCommandStatusNoSuchSession)],
      FBInvalidArgumentException: @[@(FBCommandStatusInvalidArgument)],
      FBElementAttributeUnknownException: @[@(FBCommandStatusInvalidSelector)],
      FBAlertObstructingElementException: @[@(FBCommandStatusUnexpectedAlertPresent), @"Alert is obstructing view"],
      FBApplicationCrashedException: @[@(FBCommandStatusApplicationCrashDetected)],
      FBInvalidXPathException: @[@(FBCommandStatusInvalidXPathSelector)],
      FBClassChainQueryParseException: @[@(FBCommandStatusInvalidSelector)],
      FBElementNotVisibleException: @[@(FBCommandStatusElementNotVisible)],
    };
  });

  for (NSString *exceptionName in exceptionsMapping) {
    NSArray *status = [exceptionsMapping valueForKey:exceptionName];
    if (nil == status) {
      continue;
    }

    NSUInteger statusValue = [[status objectAtIndex:0] integerValue];
    id<FBResponsePayload> payload = [status count] < 2
      ? FBResponseWithStatus(statusValue, [exception description])
      : FBResponseWithStatus(statusValue, [[status objectAtIndex:1] stringValue]);
    [payload dispatchWithResponse:response];
    return YES;
  }

  return NO;
}

@end
