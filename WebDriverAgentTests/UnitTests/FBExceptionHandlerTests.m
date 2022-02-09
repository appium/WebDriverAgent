/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBAlert.h"
#import "FBExceptionHandler.h"
#import "FBExceptions.h"


@interface RouteResponseDouble : NSObject
- (void)setHeader:(NSString *)field value:(NSString *)value;
- (void)setStatusCode:(NSUInteger)code;
- (void)respondWithData:(NSData *)data;
@end

@implementation RouteResponseDouble
- (void)setHeader:(NSString *)field value:(NSString *)value {}
- (void)setStatusCode:(NSUInteger)code {}
- (void)respondWithData:(NSData *)data {}
@end


@interface FBExceptionHandlerTests : XCTestCase
@property (nonatomic) FBExceptionHandler *exceptionHandler;
@end

@implementation FBExceptionHandlerTests

- (void)setUp
{
  self.exceptionHandler = [FBExceptionHandler new];
}

- (void)testMatchingErrorHandling
{
  NSException *exception = [NSException exceptionWithName:FBElementNotVisibleException
                                                   reason:@"reason"
                                                 userInfo:@{}];
  [self.exceptionHandler handleException:exception
                             forResponse:(RouteResponse *)[RouteResponseDouble new]];
}

- (void)testNonMatchingErrorHandling
{
  NSException *exception = [NSException exceptionWithName:@"something"
                                                   reason:@"reason"
                                                 userInfo:@{}];
  [self.exceptionHandler handleException:exception
                             forResponse:(RouteResponse *)[RouteResponseDouble new]];
}


@end
