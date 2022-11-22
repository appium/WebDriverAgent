/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCElementSnapshotWrapper.h"

#import "FBElementUtils.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wprotocol"

@implementation FBXCElementSnapshotWrapper

- (instancetype)initWithSnapshot:(id<FBXCElementSnapshot>)snapshot;
{
  self->_snapshot = snapshot;
  return self;
}

+ (instancetype)ensureWrapped:(id<FBXCElementSnapshot>)snapshot
{
  if (nil == snapshot) {
    return nil;
  }
  return [(NSObject *)snapshot isKindOfClass:self.class]
    ? (FBXCElementSnapshotWrapper *)snapshot
    : [[FBXCElementSnapshotWrapper alloc] initWithSnapshot:snapshot];
}

// Attributes are queried most often,
// so we prefer them to have direct accessors defined here
// rather than to use message forwarding via forwardingTargetForSelector,
// which is slow

- (NSString *)identifier
{
  return self.snapshot.identifier;
}

- (CGRect)frame
{
  return self.snapshot.frame;
}

- (id)value
{
  return self.snapshot.value;
}

- (NSString *)title
{
  return self.snapshot.title;
}

- (NSString *)label
{
  return self.snapshot.label;
}

- (XCUIElementType)elementType
{
  return self.snapshot.elementType;
}

- (BOOL)isEnabled
{
  return self.snapshot.enabled;
}

- (XCUIUserInterfaceSizeClass)horizontalSizeClass
{
  return self.snapshot.horizontalSizeClass;
}

- (XCUIUserInterfaceSizeClass)verticalSizeClass
{
  return self.snapshot.verticalSizeClass;
}

- (NSString *)placeholderValue
{
  return self.snapshot.placeholderValue;
}

- (BOOL)isSelected
{
  return self.snapshot.selected;
}

#if !TARGET_OS_OSX
- (BOOL)hasFocus
{
  return self.snapshot.hasFocus;
}
#endif

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  static dispatch_once_t onceToken;
  static NSSet<NSString *> *names;
  dispatch_once(&onceToken, ^{
    names = [FBElementUtils selectorNamesWithProtocol:@protocol(FBXCElementSnapshot)];
  });
  return [names containsObject:NSStringFromSelector(aSelector)] ? self.snapshot : nil;
}

@end

#pragma clang diagnostic pop
