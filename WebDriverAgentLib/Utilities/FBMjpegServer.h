/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
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

/**
 The socket that owns this instance as its delegate. Clients are bare nw_connection_t values
 with no write method of their own, so frame writes are routed through
 -[FBTCPSocket writeData:toClient:]. Must be set before streaming starts.
 */
@property (nonatomic, weak, nullable) FBTCPSocket *socket;

/**
 Stops screenshot broadcasting and prevents future scheduling.
 */
- (void)stopStreaming;

@end

NS_ASSUME_NONNULL_END
