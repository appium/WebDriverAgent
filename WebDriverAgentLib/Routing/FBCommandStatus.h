/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <WebDriverAgentLib/FBHTTPStatusCodes.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBCommandStatus : NSObject

@property (nonatomic, nullable, readonly) id value;
@property (nonatomic, nullable, readonly) NSString* error;
@property (nonatomic, nullable, readonly) NSString* message;
@property (nonatomic, nullable, readonly) NSString* traceback;
@property (nonatomic, readonly) HTTPStatusCode statusCode;
@property (nonatomic, readonly) BOOL hasError;

+ (instancetype)ok;

+ (instancetype)okWithValue:(nullable id)value;

+ (instancetype)unknownErrorWithMessage:(nullable NSString *)message
                              traceback:(nullable NSString *)traceback;

+ (instancetype)unsupportedOperationErrorWithMessage:(nullable NSString *)message
                                           traceback:(nullable NSString *)traceback;

+ (instancetype)unableToCaptureScreenErrorWithMessage:(nullable NSString *)message
                                            traceback:(nullable NSString *)traceback;

+ (instancetype)noSuchElementErrorWithMessage:(nullable NSString *)message
                                    traceback:(nullable NSString *)traceback;

+ (instancetype)invalidElementStateErrorWithMessage:(nullable NSString *)message
                                          traceback:(nullable NSString *)traceback;

+ (instancetype)invalidArgumentErrorWithMessage:(nullable NSString *)message
                                      traceback:(nullable NSString *)traceback;

+ (instancetype)staleElementReferenceErrorWithMessage:(nullable NSString *)message
                                            traceback:(nullable NSString *)traceback;

+ (instancetype)invalidSelectorErrorWithMessage:(nullable NSString *)message
                                      traceback:(nullable NSString *)traceback;

+ (instancetype)noAlertOpenErrorWithMessage:(nullable NSString *)message
                                  traceback:(nullable NSString *)traceback;

+ (instancetype)unexpectedAlertOpenErrorWithMessage:(nullable NSString *)message
                                          traceback:(nullable NSString *)traceback;

+ (instancetype)notImplementedErrorWithMessage:(nullable NSString *)message
                                     traceback:(nullable NSString *)traceback;

+ (instancetype)sessionNotCreatedError:(nullable NSString *)message
                             traceback:(nullable NSString *)traceback;

+ (instancetype)invalidCoordinatesErrorWithMessage:(nullable NSString *)message
                                         traceback:(nullable NSString *)traceback;

+ (instancetype)unknownCommandErrorWithMessage:(nullable NSString *)message
                                     traceback:(nullable NSString *)traceback;

+ (instancetype)timeoutErrorWithMessage:(nullable NSString *)message
                              traceback:(nullable NSString *)traceback;

+ (instancetype)elementNotVisibleErrorWithMessage:(nullable NSString *)message
                                   traceback:(nullable NSString *)traceback;

+ (instancetype)noSuchDriverErrorWithMessage:(nullable NSString *)message
                                   traceback:(nullable NSString *)traceback;

@end

NS_ASSUME_NONNULL_END
