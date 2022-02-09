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

@interface LRUCacheNode : NSObject

/*! Node value */
@property (nonatomic, readonly) id value;
/*! Node key */
@property (nonatomic, readonly) id<NSCopying> key;
/*! Pointer to the next node */
@property (nonatomic, nullable) LRUCacheNode *next;
/*! Pointer to the previous node */
@property (nonatomic, nullable) LRUCacheNode *prev;

/**
 Factory method to create a new cache node with the given value and key

 @param value Node value
 @param key Node key
 @returns Cache node instance
 */
+ (instancetype)nodeWithValue:(id)value key:(id<NSCopying>)key;

@end

NS_ASSUME_NONNULL_END
