/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBElementCache.h"

#import "LRUCache.h"
#import "FBAlert.h"
#import "FBExceptions.h"
#import "FBXCodeCompatibility.h"
#import "XCTestPrivateSymbols.h"
#import "XCUIElement.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBUID.h"
#import "XCUIElement+FBResolve.h"
#import "XCUIElementQuery.h"

const int ELEMENT_CACHE_SIZE = 1024;

@interface FBElementCache ()
@property (nonatomic, strong) LRUCache *elementCache;
@end

@implementation FBElementCache

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }
  _elementCache = [[LRUCache alloc] initWithCapacity:ELEMENT_CACHE_SIZE];
  return self;
}

- (NSString *)storeElement:(XCUIElement *)element
{
  NSString *uuid = element.fb_cacheId;
  if (nil == uuid) {
    return nil;
  }
  @synchronized (self.elementCache) {
    [self.elementCache setObject:element forKey:uuid];
  }
  return uuid;
}

- (XCUIElement *)elementForUUID:(NSString *)uuid
{
  return [self elementForUUID:uuid checkStaleness:NO];
}

- (XCUIElement *)elementForUUID:(NSString *)uuid checkStaleness:(BOOL)checkStaleness
{
  if (!uuid) {
    NSString *reason = [NSString stringWithFormat:@"Cannot extract cached element for UUID: %@", uuid];
    @throw [NSException exceptionWithName:FBInvalidArgumentException reason:reason userInfo:@{}];
  }

  XCUIElement *element;
  @synchronized (self.elementCache) {
    element = [self.elementCache objectForKey:uuid];
  }
  if (nil == element) {
    NSString *reason = [NSString stringWithFormat:@"The element identified by \"%@\" is either not present or it has expired from the internal cache. Try to find it again", uuid];
    @throw [NSException exceptionWithName:FBStaleElementException reason:reason userInfo:@{}];
  }
  if (checkStaleness) {
    @try {
      [element fb_standardSnapshot];
    } @catch (NSException *exception) {
      //  if the snapshot method threw FBStaleElementException (implying the element is stale) we need to explicitly remove it from the cache, PR: https://github.com/appium/WebDriverAgent/pull/985
      if ([exception.name isEqualToString:FBStaleElementException]) {
        @synchronized (self.elementCache) {
          [self.elementCache removeObjectForKey:uuid];
        }
      }
      @throw exception;
    }
  }
  return element;
}

- (BOOL)hasElementWithUUID:(NSString *)uuid
{
  if (nil == uuid) {
    return NO;
  }
  @synchronized (self.elementCache) {
    return nil != [self.elementCache objectForKey:(NSString *)uuid];
  }
}

@end
