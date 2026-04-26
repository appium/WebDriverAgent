/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Optional reverse TCP tunnel for NAT-restricted environments.

 When configured, this module opens an outbound TCP connection to an external
 relay server, allowing WDA to be controlled in environments where inbound
 connections to port 8100 are not feasible (symmetric NAT, multi-layer
 firewalls, cellular networks, VPN tunnels, etc.).

 The tunnel uses an 8-byte header framing protocol (4-byte payload length +
 4-byte request ID, both big-endian) to multiplex HTTP request/response pairs
 over a single persistent connection with reliable request-response correlation.

 Connection failures trigger automatic reconnection after a configurable delay.
 */
@interface FBReverseTunnel : NSObject

/**
 Starts the reverse tunnel to the specified relay host and port.

 @param host The relay server hostname or IP address
 @param port The relay server port
 @param localPort The local WDA HTTP server port to forward requests to
 */
+ (void)startWithHost:(NSString *)host
                 port:(NSInteger)port
            localPort:(NSUInteger)localPort;

@end

NS_ASSUME_NONNULL_END
