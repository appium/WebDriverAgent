/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBResponsePayload.h"

#import "FBElementCache.h"
#import "FBResponseJSONPayload.h"
#import "FBSession.h"
#import "FBMathUtils.h"
#import "FBConfiguration.h"
#import "FBMacros.h"
#import "FBProtocolHelpers.h"
#import "XCUIElementQuery.h"
#import "XCUIElement+FBResolve.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

NSString *arbitraryAttrPrefix = @"attribute/";

id<FBResponsePayload> FBResponseWithOK(void)
{
  return FBResponseWithStatus(FBCommandStatus.ok);
}

id<FBResponsePayload> FBResponseWithObject(id object)
{
  return FBResponseWithStatus([FBCommandStatus okWithValue:object]);
}

id<FBResponsePayload> FBResponseWithCachedElement(XCUIElement *element, FBElementCache *elementCache, BOOL compact)
{
  BOOL useNativeCachingStrategy = nil == FBSession.activeSession
    ? YES
    : FBSession.activeSession.useNativeCachingStrategy;
  [elementCache storeElement:(useNativeCachingStrategy ? element : element.fb_stableInstance)];
  return FBResponseWithStatus([FBCommandStatus okWithValue:FBDictionaryResponseWithElement(element, compact)]);
}

id<FBResponsePayload> FBResponseWithCachedElements(NSArray<XCUIElement *> *elements, FBElementCache *elementCache, BOOL compact)
{
  NSMutableArray *elementsResponse = [NSMutableArray array];
  BOOL useNativeCachingStrategy = nil == FBSession.activeSession
    ? YES
    : FBSession.activeSession.useNativeCachingStrategy;
  for (XCUIElement *element in elements) {
    [elementCache storeElement:(useNativeCachingStrategy ? element : element.fb_stableInstance)];
    [elementsResponse addObject:FBDictionaryResponseWithElement(element, compact)];
  }
  return FBResponseWithStatus([FBCommandStatus okWithValue:elementsResponse]);
}

id<FBResponsePayload> FBResponseWithUnknownError(NSError *error)
{
  return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description traceback:nil]);
}

id<FBResponsePayload> FBResponseWithUnknownErrorFormat(NSString *format, ...)
{
  va_list argList;
  va_start(argList, format);
  NSString *errorMessage = [[NSString alloc] initWithFormat:format arguments:argList];
  id<FBResponsePayload> payload = FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:errorMessage
                                                                                      traceback:nil]);
  va_end(argList);
  return payload;
}

id<FBResponsePayload> FBResponseWithStatus(FBCommandStatus *status)
{
  NSMutableDictionary* response = [NSMutableDictionary dictionary];
  response[@"sessionId"] = [FBSession activeSession].identifier ?: NSNull.null;
  if (nil == status.error) {
    response[@"value"] = status.value ?: NSNull.null;
  } else {
    response[@"value"] = @{
      @"error": (id)status.error,
      @"message": status.message ?: @"",
      @"traceback": status.traceback ?: @""
    };
  }
  return [[FBResponseJSONPayload alloc] initWithDictionary:response.copy
                                            httpStatusCode:status.statusCode];
}

inline NSDictionary *FBDictionaryResponseWithElement(XCUIElement *element, BOOL compact)
{
  id<FBXCElementSnapshot> snapshot = nil;
  if (nil != element.query.rootElementSnapshot) {
    snapshot = element.fb_cachedSnapshot;
  }
  if (nil == snapshot) {
    snapshot = element.lastSnapshot ?: element.fb_takeSnapshot;
  }
  NSDictionary *compactResult = FBToElementDict((NSString *)[FBXCElementSnapshotWrapper wdUIDWithSnapshot:snapshot]);
  if (compact) {
    return compactResult;
  }

  NSMutableDictionary *result = compactResult.mutableCopy;
  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:snapshot];
  NSArray *fields = [FBConfiguration.elementResponseAttributes componentsSeparatedByString:@","];
  for (NSString *field in fields) {
    // 'name' here is the w3c-approved identifier for what we mean by 'type'
    if ([field isEqualToString:@"name"] || [field isEqualToString:@"type"]) {
      result[field] = wrappedSnapshot.wdType;
    } else if ([field isEqualToString:@"text"]) {
      result[field] = FBFirstNonEmptyValue(wrappedSnapshot.wdValue, wrappedSnapshot.wdLabel) ?: [NSNull null];
    } else if ([field isEqualToString:@"rect"]) {
      result[field] = wrappedSnapshot.wdRect;
    } else if ([field isEqualToString:@"enabled"]) {
      result[field] = @(wrappedSnapshot.wdEnabled);
    } else if ([field isEqualToString:@"displayed"]) {
      result[field] = @(wrappedSnapshot.wdVisible);
    } else if ([field isEqualToString:@"selected"]) {
      result[field] = @(wrappedSnapshot.wdSelected);
    } else if ([field isEqualToString:@"label"]) {
      result[field] = wrappedSnapshot.wdLabel ?: [NSNull null];
    } else if ([field hasPrefix:arbitraryAttrPrefix]) {
      NSString *attributeName = [field substringFromIndex:[arbitraryAttrPrefix length]];
      result[field] = [wrappedSnapshot fb_valueForWDAttributeName:attributeName] ?: [NSNull null];
    }
  }
  return result.copy;
}
