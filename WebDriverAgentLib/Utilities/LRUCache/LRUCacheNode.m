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

#import "LRUCacheNode.h"

@interface LRUCacheNode ()
@property (nonatomic, readwrite) id value;
@property (nonatomic, readwrite) id<NSCopying> key;

- (instancetype)initWithValue:(id)value key:(id<NSCopying>)key;
@end

@implementation LRUCacheNode

- (instancetype)initWithValue:(id)value key:(id<NSCopying>)key
{
  if (nil == value) {
    return nil;
  }

  if ((self = [super init])) {
    _value = value;
    _key = key;
  }
  return self;
}

+ (instancetype)nodeWithValue:(id)value key:(id<NSCopying>)key
{
  return [[LRUCacheNode alloc] initWithValue:value key:key];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ %@", self.value, self.next];
}

@end
