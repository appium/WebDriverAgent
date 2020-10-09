/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBElementCache.h"

#import <YYCache/YYCache.h>
#import "FBAlert.h"
#import "FBExceptions.h"
#import "FBXCodeCompatibility.h"
#import "XCUIElement.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBUID.h"

const int ELEMENT_CACHE_SIZE = 1024;

@interface FBElementCache ()
@property (atomic, strong) YYMemoryCache *elementCache;
@end

@implementation FBElementCache

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }
  _elementCache = [[YYMemoryCache alloc] init];
  _elementCache.countLimit = ELEMENT_CACHE_SIZE;
  return self;
}

- (NSString *)storeElement:(XCUIElement *)element
{
  NSString *uuid = element.fb_uid;
  if (nil == uuid) {
    return nil;
  }
  [self.elementCache setObject:element forKey:uuid];
  return uuid;
}

- (XCUIElement *)elementForUUID:(NSString *)uuid
{
  if (!uuid) {
    NSString *reason = [NSString stringWithFormat:@"Cannot extract cached element for UUID: %@", uuid];
    @throw [NSException exceptionWithName:FBInvalidArgumentException reason:reason userInfo:@{}];
  }

  XCUIElement *element = [self.elementCache objectForKey:uuid];
  BOOL isStale = NO;
  if (element.query.fb_isSnapshotsCachingSupported && nil == element.fb_cachedSnapshot && ![element fb_nativeResolve]) {
    isStale = YES;
  }
  if (isStale || nil == element) {
    NSString *reason = [NSString stringWithFormat:@"The previously found element \"%@\" is not present on the current page anymore", element ? element.description : uuid];
    @throw [NSException exceptionWithName:FBStaleElementException reason:reason userInfo:@{}];
  }
  return element;
}

- (BOOL)hasElementWithUUID:(NSString *)uuid
{
  return nil == uuid ? NO : [self.elementCache containsObjectForKey:(NSString *)uuid];
}

@end
