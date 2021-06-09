/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LRUCache : NSObject

/*! Maximum cache capacity. Could only be set in the constructor */
@property (nonatomic, readonly) NSUInteger capacity;

/**
 Constructs a new LRU cache instance with the given capacity

 @param capacity Maximum cache capacity
 */
- (instancetype)initWithCapacity:(NSUInteger)capacity;

/**
 Puts a new object into the cache. nil cannot be stored in the cache.

 @param object Object to put
 @param key Object's key
 */
- (void)setObject:(id)object forKey:(id<NSCopying>)key;

/**
 Retrieves an object from the cache. Every time this method is called the matched
 object is bumped in the cache (if exists)

 @param key Object's key
 @returns Either the stored instance or nil if the object does not exist or has expired
 */
- (nullable id)objectForKey:(id<NSCopying>)key;

/**
 Retrieves all values from the cache. No bump is performed

 @return Array of all cache values
 */
- (NSArray *)allObjects;

@end

NS_ASSUME_NONNULL_END
