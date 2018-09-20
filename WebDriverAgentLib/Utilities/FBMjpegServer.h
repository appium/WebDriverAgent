/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTCPSocket.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBMjpegServer : NSObject <FBTCPSocketDelegate>

/**
 The default constructor for the screenshot bradcaster service.
 This service sends low resolution screenshots 10 times per seconds
 to all connected clients.
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
