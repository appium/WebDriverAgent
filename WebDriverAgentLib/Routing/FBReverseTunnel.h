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

 When WDA_RELAY_HOST is set, this module opens an outbound TCP connection
 to an external relay server, allowing WDA to be controlled in environments
 where inbound connections to port 8100 are not feasible (symmetric NAT,
 multi-layer firewalls, VPN tunnels, etc.).

 The tunnel uses a simple 4-byte big-endian length-prefixed framing protocol
 to multiplex HTTP request/response pairs over a single persistent connection.

 When WDA_RELAY_HOST is not set, this module is completely inactive.
 */
@interface FBReverseTunnel : NSObject

/**
 Starts the reverse tunnel if WDA_RELAY_HOST is configured.
 Does nothing if the environment variable is not set (default behavior unchanged).

 @param localPort The local WDA HTTP server port to forward requests to
 */
+ (void)startIfConfiguredWithLocalPort:(NSUInteger)localPort;

@end

NS_ASSUME_NONNULL_END
