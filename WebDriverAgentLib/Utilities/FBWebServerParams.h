/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBWebServerParams : NSObject

/** The local port number WDA server is running on */
@property (nonatomic, nullable) NSNumber *port;

+ (id)sharedInstance;

@end

NS_ASSUME_NONNULL_END
