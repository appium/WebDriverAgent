/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class XCUIElement;

NS_ASSUME_NONNULL_BEGIN

// This constant defines the size of the element cache, which puts an upper limit
// on the amount of elements which can be stored in the cache.
// Based on the data in https://github.com/facebook/WebDriverAgent/pull/896, each
// element consumes about 100KB of memory; so 1024 elements would consume 100 MB of
// memory.
extern const int ELEMENT_CACHE_SIZE;

@interface FBElementCache : NSObject

/**
 Stores element in cache

 @param element element to store
 @return element's uuid or nil in case the element uid cannnot be extracted
 */
- (nullable NSString *)storeElement:(XCUIElement *)element;

/**
 Returns cached element resolved with default snapshot attributes

 @param uuid uuid of element to fetch
 @return element
 @throws FBStaleElementException if the found element is not present in DOM anymore
 @throws FBInvalidArgumentException if uuid is nil
 */
- (XCUIElement *)elementForUUID:(NSString *)uuid;

/**
 Returns cached element

 @param uuid uuid of element to fetch
 @param additionalAttributes Add additonal attribute names if the snapshot should contain
 them in `addtionalAttributes` section. nil value resolves the snapshot with standard attributes.
 @param maxDepth The maximum depth of the snapshot. Only works if additional attributes are provided.
 `nil` value means to use the default maximum depth value.
 @return element
 @throws FBStaleElementException if the found element is not present in DOM anymore
 @throws FBInvalidArgumentException if uuid is nil
 */
- (XCUIElement *)elementForUUID:(NSString *)uuid
 resolveForAdditionalAttributes:(nullable NSArray <NSString *> *)additionalAttributes
                    andMaxDepth:(nullable NSNumber *)maxDepth;

/**
 Checks element existence in the cache

 @returns YES if the element with the given UUID is present in cache
 */
- (BOOL)hasElementWithUUID:(nullable NSString *)uuid;

@end

NS_ASSUME_NONNULL_END
