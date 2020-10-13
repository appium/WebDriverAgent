/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <WebDriverAgentLib/FBCommandStatus.h>

@class FBElementCache;
@class RouteResponse;
@class XCUIElement;
@protocol FBResponsePayload;

NS_ASSUME_NONNULL_BEGIN

/**
 Returns 'FBCommandStatusNoError' response payload
 */
id<FBResponsePayload> FBResponseWithOK(void);

/**
 Returns 'FBCommandStatusNoError' response payload with given 'object'
 */
id<FBResponsePayload> FBResponseWithObject(id _Nullable object);

/**
 Returns 'FBCommandStatusNoError' response payload with given 'element', which will be also cached in 'elementCache'
 */
id<FBResponsePayload> FBResponseWithCachedElement(XCUIElement *element, FBElementCache *elementCache, BOOL compact);

/**
 Returns 'FBCommandStatusNoError' response payload with given array of 'elements', which will be also cached in 'elementCache'
 */
id<FBResponsePayload> FBResponseWithCachedElements(NSArray<XCUIElement *> *elements, FBElementCache *elementCache, BOOL compact);

/**
 Returns 'FBCommandStatusUnhandled' response payload with given error's description
 */
id<FBResponsePayload> FBResponseWithUnknownError(NSError *error);

/**
 Returns 'FBCommandStatusUnhandled' response payload with given error message
 */
id<FBResponsePayload> FBResponseWithUnknownErrorFormat(NSString *errorFormat, ...) NS_FORMAT_FUNCTION(1,2);

/**
 Returns 'status' response payload with given object
 */
id<FBResponsePayload> FBResponseWithStatus(FBCommandStatus *status);

/**
 Returns a response payload as a NSDictionary for given element.
 Set compact=NO to include further attributes (defined by FBConfiguration.elementResponseAttributes)
 */
NSDictionary *FBDictionaryResponseWithElement(XCUIElement *element, BOOL compact);


/**
 Protocol for objects that can dispatch some kind of a payload for given 'response'
 */
@protocol FBResponsePayload <NSObject>

/**
 Dispatch constructed payload into given response
 */
- (void)dispatchWithResponse:(RouteResponse *)response;

@end

NS_ASSUME_NONNULL_END
