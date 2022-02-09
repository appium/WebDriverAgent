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
  NSAssert(nil != object && nil != key, @"LRUCache cannot store nil objects");

  LRUCacheNode *previousNode = self.store[key];
  if (nil != previousNode) {
    [self removeNode:previousNode];
  }

  LRUCacheNode *newNode = [LRUCacheNode nodeWithValue:object key:key];
  self.store[key] = newNode;
  [self addNodeToHead:newNode];
  if (nil == previousNode) {
    [self alignSize];
  }
}

- (id)objectForKey:(id<NSCopying>)key
{
  LRUCacheNode *node = self.store[key];
  return [self moveNodeToHead:node].value;
}

- (NSArray *)allObjects
{
  NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:self.store.count];
  LRUCacheNode *node = self.headNode;
  while (node != nil) {
    [result addObject:node.value];
    node = node.next;
  }
  return result.copy;
}

- (nullable LRUCacheNode *)moveNodeToHead:(nullable LRUCacheNode *)node
{
  if (nil == node || node == self.headNode) {
    return node;
  }

  LRUCacheNode *previousNode = node.prev;
  if (nil != previousNode) {
    previousNode.next = node.next;
  }
  LRUCacheNode *nextNode = node.next;
  if (nil != nextNode) {
    nextNode.prev = node.prev;
  }
  if (node == self.tailNode) {
    self.tailNode = previousNode;
  }
  return [self addNodeToHead:node];
}

- (void)removeNode:(nullable LRUCacheNode *)node
{
  if (nil == node) {
    return;
  }

  if (nil != node.next) {
    node.next.prev = node.prev;
  }
  if (node == self.headNode) {
    self.headNode = node.next;
  }
  if (nil != node.prev) {
    node.prev.next = node.next;
  }
  if (node == self.tailNode) {
    self.tailNode = node.prev;
  }
  [self.store removeObjectForKey:(id)node.key];
}

- (nullable LRUCacheNode *)addNodeToHead:(nullable LRUCacheNode *)node
{
  if (nil == node || node == self.headNode) {
    return node;
  }

  LRUCacheNode *previousHead = self.headNode;
  if (nil != previousHead) {
    previousHead.prev = node;
  }
  node.next = previousHead;
  node.prev = nil;
  self.headNode = node;
  if (nil == self.tailNode) {
    self.tailNode = previousHead ?: node;
  }
  return node;
}

- (void)alignSize
{
  if (self.store.count > self.capacity && nil != self.tailNode) {
    [self removeNode:self.tailNode];
  }
}

@end
