/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCommandStatus.h"

static NSString *const FB_UNKNOWN_ERROR = @"unknown error";
static const HTTPStatusCode FB_UNKNOWN_ERROR_CODE = kHTTPStatusCodeInternalServerError;
static NSString *const FB_UNKNOWN_ERROR_MSG = @"An unknown server-side error occurred while processing the command";

static NSString *const FB_UNABLE_TO_CAPTURE_ERROR = @"unable to capture screen";
static const HTTPStatusCode FB_UNABLE_TO_CAPTURE_ERROR_CODE = kHTTPStatusCodeInternalServerError;
static NSString *const FB_UNABLE_TO_CAPTURE_MSG = @"A screen capture was made impossible";

static NSString *const FB_NO_SUCH_ELEMENT_ERROR = @"no such element";
static const HTTPStatusCode FB_NO_SUCH_ELEMENT_ERROR_CODE = kHTTPStatusCodeNotFound;
static NSString *const FB_NO_SUCH_ELEMENT_MSG = @"An element could not be located on the page using the given search parameters";

static NSString *const FB_INVALID_ELEMENT_STATE_ERROR = @"invalid element state";
static const HTTPStatusCode FB_INVALID_ELEMENT_STATE_ERROR_CODE = kHTTPStatusCodeBadRequest;
static NSString *const FB_INVALID_ELEMENT_STATE_MSG = @"An element command could not be completed because the element is in an invalid state (e.g. attempting to click a disabled element)";

static NSString *const FB_INVALID_ARGUMENT_ERROR = @"invalid argument";
static const HTTPStatusCode FB_INVALID_ARGUMENT_ERROR_CODE = kHTTPStatusCodeBadRequest;
static NSString *const FB_INVALID_ARGUMENT_MSG = @"The arguments passed to the command are either invalid or malformed";

static NSString *const FB_STALE_ELEMENT_REF_ERROR = @"stale element reference";
static const HTTPStatusCode FB_STALE_ELEMENT_REF_ERROR_CODE = kHTTPStatusCodeNotFound;
static NSString *const FB_STALE_ELEMENT_REF_MSG = @"An element command failed because the referenced element is no longer attached to the DOM";

static NSString *const FB_INVALID_SELECTOR_ERROR = @"invalid selector";
static const HTTPStatusCode FB_INVALID_SELECTOR_ERROR_CODE = kHTTPStatusCodeBadRequest;
static NSString *const FB_INVALID_SELECTOR_MSG = @"Argument was an invalid selector (e.g. XPath/Class Chain)";

static NSString *const FB_NO_ALERT_OPEN_ERROR = @"no such alert";
static const HTTPStatusCode FB_NO_ALERT_OPEN_ERROR_CODE = kHTTPStatusCodeNotFound;
static NSString *const FB_NO_ALERT_OPEN_MSG = @"An attempt was made to operate on a modal dialog when one was not open";

static NSString *const FB_UNEXPECTED_ALERT_OPEN_ERROR = @"unexpected alert open";
static const HTTPStatusCode FB_UNEXPECTED_ALERT_OPEN_ERROR_CODE = kHTTPStatusCodeInternalServerError;
static NSString *const FB_UNEXPECTED_ALERT_OPEN_MSG = @"A modal dialog was open, blocking this operation";

static NSString *const FB_NOT_IMPLEMENTED_ERROR = @"unknown method";
static const HTTPStatusCode FB_NOT_IMPLEMENTED_ERROR_CODE = kHTTPStatusCodeMethodNotAllowed;
static NSString *const FB_NOT_IMPLEMENTED_MSG = @"Method is not implemented";

static NSString *const FB_SESSION_NOT_CREATED_ERROR = @"session not created";
static const HTTPStatusCode FB_SESSION_NOT_CREATED_ERROR_CODE = kHTTPStatusCodeInternalServerError;
static NSString *const FB_SESSION_NOT_CREATED_MSG = @"A new session could not be created";

static NSString *const FB_INVALID_COORDINATES_ERROR = @"invalid coordinates";
static const HTTPStatusCode FB_INVALID_COORDINATES_ERROR_CODE = kHTTPStatusCodeBadRequest;
static NSString *const FB_INVALID_COORDINATES_MSG = @"The coordinates provided to an interactions operation are invalid";

static NSString *const FB_UNSUPPORTED_OPERATION_ERROR = @"unsupported operation";
static const HTTPStatusCode FB_UNSUPPORTED_OPERATION_ERROR_CODE = kHTTPStatusCodeInternalServerError;
static NSString *const FB_UNSUPPORTED_OPERATION_ERROR_MSG = @"The requested operation is not supported";

static NSString *const FB_UNKNOWN_COMMAND_ERROR = @"unknown command";
static const HTTPStatusCode FB_UNKNOWN_COMMAND_ERROR_CODE = kHTTPStatusCodeNotFound;
static NSString *const FB_UNKNOWN_COMMAND_MSG = @"The requested resource could not be found, or a request was received using an HTTP method that is not supported by the mapped resource";

static NSString *const FB_TIMEOUT_ERROR = @"timeout";
static const HTTPStatusCode FB_TIMEOUT_ERROR_CODE = kHTTPStatusCodeRequestTimeout;
static NSString *const FB_TIMEOUT_MSG = @"An operation did not complete before its timeout expired";

static NSString *const FB_ELEMENT_NOT_VISIBLE_ERROR = @"element not visible";
static const HTTPStatusCode FB_ELEMENT_NOT_VISIBLE_ERROR_CODE = kHTTPStatusCodeBadRequest;
static NSString *const FB_ELEMENT_NOT_VISIBLE_MSG = @"An element command could not be completed because the element is not visible on the page";

static NSString *const FB_NO_SUCH_DRIVER_ERROR = @"invalid session id";
static const HTTPStatusCode FB_NO_SUCH_DRIVER_ERROR_CODE = kHTTPStatusCodeNotFound;
static NSString *const FB_NO_SUCH_DRIVER_MSG = @"A session is either terminated or not started";


@implementation FBCommandStatus

- (instancetype)initWithValue:(nullable id)value
{
  self = [super init];
  if (self) {
    _value = value;
    _message = nil;
    _error = nil;
    _traceback = nil;
    _statusCode = kHTTPStatusCodeOK;
  }
  return self;
}

- (instancetype)initWithError:(NSString *)error
                   statusCode:(HTTPStatusCode)statusCode
                      message:(NSString *)message
                    traceback:(nullable NSString *)traceback
{
  self = [super init];
  if (self) {
    _error = error;
    _statusCode = statusCode;
    _message = message;
    _traceback = traceback;
    _value = nil;
  }
  return self;
}

+ (instancetype)ok
{
  return [[FBCommandStatus alloc] initWithValue:nil];
}

+ (instancetype)okWithValue:(id)value
{
  return [[FBCommandStatus alloc] initWithValue:value];
}

+ (instancetype)unknownErrorWithMessage:(NSString *)message
                              traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_UNKNOWN_ERROR
                                     statusCode:FB_UNKNOWN_ERROR_CODE
                                        message:message ?: FB_UNKNOWN_ERROR_MSG
                                      traceback:traceback];
}

+ (instancetype)unsupportedOperationErrorWithMessage:(NSString *)message
                                           traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_UNSUPPORTED_OPERATION_ERROR
                                     statusCode:FB_UNSUPPORTED_OPERATION_ERROR_CODE
                                        message:message ?: FB_UNSUPPORTED_OPERATION_ERROR_MSG
                                      traceback:traceback];
}

+ (instancetype)unableToCaptureScreenErrorWithMessage:(NSString *)message
                                            traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_UNABLE_TO_CAPTURE_ERROR
                                     statusCode:FB_UNABLE_TO_CAPTURE_ERROR_CODE
                                        message:message ?: FB_UNABLE_TO_CAPTURE_MSG
                                      traceback:traceback];
}

+ (instancetype)noSuchElementErrorWithMessage:(NSString *)message
                                    traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_NO_SUCH_ELEMENT_ERROR
                                     statusCode:FB_NO_SUCH_ELEMENT_ERROR_CODE
                                        message:message ?: FB_NO_SUCH_ELEMENT_MSG
                                      traceback:traceback];
}

+ (instancetype)invalidElementStateErrorWithMessage:(NSString *)message
                                          traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_INVALID_ELEMENT_STATE_ERROR
                                     statusCode:FB_INVALID_ELEMENT_STATE_ERROR_CODE
                                        message:message ?: FB_INVALID_ELEMENT_STATE_MSG
                                      traceback:traceback];
}

+ (instancetype)invalidArgumentErrorWithMessage:(NSString *)message
                                      traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_INVALID_ARGUMENT_ERROR
                                     statusCode:FB_INVALID_ARGUMENT_ERROR_CODE
                                        message:message ?: FB_INVALID_ARGUMENT_MSG
                                      traceback:traceback];
}

+ (instancetype)staleElementReferenceErrorWithMessage:(NSString *)message
                                            traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_STALE_ELEMENT_REF_ERROR
                                     statusCode:FB_STALE_ELEMENT_REF_ERROR_CODE
                                        message:message ?: FB_STALE_ELEMENT_REF_MSG
                                      traceback:traceback];
}

+ (instancetype)invalidSelectorErrorWithMessage:(NSString *)message
                                      traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_INVALID_SELECTOR_ERROR
                                     statusCode:FB_INVALID_SELECTOR_ERROR_CODE
                                        message:message ?: FB_INVALID_SELECTOR_MSG
                                      traceback:traceback];
}

+ (instancetype)noAlertOpenErrorWithMessage:(NSString *)message
                                  traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_NO_ALERT_OPEN_ERROR
                                     statusCode:FB_NO_ALERT_OPEN_ERROR_CODE
                                        message:message ?: FB_NO_ALERT_OPEN_MSG
                                      traceback:traceback];
}

+ (instancetype)unexpectedAlertOpenErrorWithMessage:(NSString *)message
                                          traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_UNEXPECTED_ALERT_OPEN_ERROR
                                     statusCode:FB_UNEXPECTED_ALERT_OPEN_ERROR_CODE
                                        message:message ?: FB_UNEXPECTED_ALERT_OPEN_MSG
                                      traceback:traceback];
}

+ (instancetype)notImplementedErrorWithMessage:(NSString *)message
                                     traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_NOT_IMPLEMENTED_ERROR
                                     statusCode:FB_NOT_IMPLEMENTED_ERROR_CODE
                                        message:message ?: FB_NOT_IMPLEMENTED_MSG
                                      traceback:traceback];
}

+ (instancetype)sessionNotCreatedError:(NSString *)message
                             traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_SESSION_NOT_CREATED_ERROR
                                     statusCode:FB_SESSION_NOT_CREATED_ERROR_CODE
                                        message:message ?: FB_SESSION_NOT_CREATED_MSG
                                      traceback:traceback];
}

+ (instancetype)invalidCoordinatesErrorWithMessage:(NSString *)message
                                         traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_INVALID_COORDINATES_ERROR
                                     statusCode:FB_INVALID_COORDINATES_ERROR_CODE
                                        message:message ?: FB_INVALID_COORDINATES_MSG
                                      traceback:traceback];
}

+ (instancetype)unknownCommandErrorWithMessage:(NSString *)message
                                     traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_UNKNOWN_COMMAND_ERROR
                                     statusCode:FB_UNKNOWN_COMMAND_ERROR_CODE
                                        message:message ?: FB_UNKNOWN_COMMAND_MSG
                                      traceback:traceback];
}

+ (instancetype)timeoutErrorWithMessage:(NSString *)message
                              traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_TIMEOUT_ERROR
                                     statusCode:FB_TIMEOUT_ERROR_CODE
                                        message:message ?: FB_TIMEOUT_MSG
                                      traceback:traceback];
}

+ (instancetype)elementNotVisibleErrorWithMessage:(NSString *)message
                                        traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_ELEMENT_NOT_VISIBLE_ERROR
                                     statusCode:FB_ELEMENT_NOT_VISIBLE_ERROR_CODE
                                        message:message ?: FB_ELEMENT_NOT_VISIBLE_MSG
                                      traceback:traceback];
}

+ (instancetype)noSuchDriverErrorWithMessage:(NSString *)message
                                   traceback:(NSString *)traceback
{
  return [[FBCommandStatus alloc] initWithError:FB_NO_SUCH_DRIVER_ERROR
                                     statusCode:FB_NO_SUCH_DRIVER_ERROR_CODE
                                        message:message ?: FB_NO_SUCH_DRIVER_MSG
                                      traceback:traceback];
}

@end
