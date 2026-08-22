/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@class RouteResponse, FBExceptionHandler;
@protocol FBWebServerDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 HTTP and USB service wrapper, handling requests and responses
 */
@interface FBWebServer : NSObject

/**
 Server delegate.
 */
@property (weak, nonatomic) id<FBWebServerDelegate> delegate;

/**
 Starts WebDriverAgent service by booting HTTP and USB server.
 If the HTTP server fails to bind (for example the whole configured port range
 is already occupied), the failure is reported to the delegate via
 `webServer:didFailToStartWithError:`. If the delegate does not implement that
 method the process is aborted, as before.
 */
- (void)startServing;

/**
 Stops WebDriverAgent service, shutting down HTTP and USB servers.
 */
- (void)stopServing;

@end

/**
 The protocol allowing the server delegate to handle messages from the server.
 */
@protocol FBWebServerDelegate <NSObject>

/**
 The server requested WebDriverAgent service shutdown.

 @param webServer Server instance.
 */
- (void)webServerDidRequestShutdown:(FBWebServer *)webServer;

@optional
/**
 Called when the server failed to start the HTTP listener, for example because
 none of the ports in the configured binding range could be bound.
 If this method is not implemented by the delegate then the process is aborted,
 preserving the previous behavior.

 @param webServer Server instance.
 @param error The actual error, that caused the server startup to fail.
 */
- (void)webServer:(FBWebServer *)webServer didFailToStartWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
