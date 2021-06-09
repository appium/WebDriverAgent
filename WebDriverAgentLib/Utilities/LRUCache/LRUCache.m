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

#import "LRUCache.h"
#import "LRUCacheNode.h"

@interface LRUCache ()
@property (nonatomic) NSMutableDictionary *store;
@property (nonatomic, nullable) LRUCacheNode *headNode;
@property (nonatomic, nullable) LRUCacheNode *tailNode;
@property (nonatomic) NSUInteger size;
@end

@implementation LRUCache

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
  if ((self = [super init])) {
    _store = [NSMutableDictionary dictionary];
    _capacity = capacity;
  }
  return self;
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key
{
  NSAssert(nil != object, @"LRUCache cannot store nil objects");

  LRUCacheNode *previousNode = self.store[key];
  LRUCacheNode *newNode = [LRUCacheNode nodeWithValue:object key:key];
  self.store[key] = newNode;
  if (nil == previousNode) {
    ++self.size;
  }
  if (previousNode == self.tailNode) {
    self.tailNode = newNode;
  }
  if (previousNode == self.headNode) {
    self.headNode = newNode;
  }

  [self bumpNode:newNode];
  [self alignSize];
}

- (id)objectForKey:(id<NSCopying>)key
{
  LRUCacheNode *node = self.store[key];
  if (nil != node) {
    [self bumpNode:node];
  }

  return node.value;
}

- (NSArray *)allObjects
{
  return (NSArray *)[self.store.allValues valueForKeyPath:@"value"];
}

- (void)bumpNode:(LRUCacheNode *)node
{
  if (node == self.headNode) {
    return;
  }

  if (node == self.tailNode) {
    self.tailNode = self.tailNode.prev;
  }

  self.headNode.prev.next = node.next;

  LRUCacheNode *prevHead = self.headNode;
  self.headNode = node;
  self.headNode.next = prevHead;
}

- (void)alignSize
{
  if (self.size <= self.capacity) {
    return;
  }

  LRUCacheNode *nextTail = self.tailNode.prev;
  [self.store removeObjectForKey:(id)self.tailNode.key];
  self.tailNode = nextTail;
  self.tailNode.next = nil;
  --self.size;
}

@end
