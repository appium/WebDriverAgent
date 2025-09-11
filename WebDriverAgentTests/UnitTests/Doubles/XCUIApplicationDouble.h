/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@interface XCUIApplicationDouble : NSObject
@property (nonatomic, assign, readonly) BOOL didTerminate;
@property (nonatomic, strong) NSString* bundleID;
@property (nonatomic) BOOL fb_shouldWaitForQuiescence;

- (BOOL)running;
@end
