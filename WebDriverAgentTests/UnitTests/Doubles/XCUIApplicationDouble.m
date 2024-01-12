/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIApplicationDouble.h"

@interface XCUIApplicationDouble ()
@property (nonatomic, assign, readwrite) BOOL didTerminate;
@end

@implementation XCUIApplicationDouble

- (instancetype)init
{
  self = [super init];
  if (self) {
    _bundleID = @"some.bundle.identifier";
  }
  return self;
}

- (void)terminate
{
  self.didTerminate = YES;
}

- (NSUInteger)processID
{
  return 0;
}

- (NSString *)bundleID
{
  return @"com.facebook.awesome";
}

- (void)fb_nativeResolve
{

}

- (id)query
{
  return nil;
}

- (BOOL)fb_shouldWaitForQuiescence
{
  return NO;
}

-(void)setFb_shouldWaitForQuiescence:(BOOL)value
{

}

- (BOOL)running
{
  return NO;
}

@end
