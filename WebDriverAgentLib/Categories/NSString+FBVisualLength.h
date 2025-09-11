/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@interface NSString (FBVisualLength)

/**
 Helper method that returns length of string with trimmed whitespaces
 */
- (NSUInteger)fb_visualLength;

@end
