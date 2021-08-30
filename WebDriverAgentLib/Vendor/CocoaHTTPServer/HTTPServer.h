#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class WebSocket;

#if TARGET_OS_IPHONE
#define IMPLEMENTED_PROTOCOLS
#else
#define IMPLEMENTED_PROTOCOLS
#endif


@interface HTTPServer : NSObject IMPLEMENTED_PROTOCOLS
{
  // Underlying asynchronous TCP/IP socket
  GCDAsyncSocket *asyncSocket;
  
  // Dispatch queues
  dispatch_queue_t serverQueue;
  dispatch_queue_t connectionQueue;
  void *IsOnServerQueueKey;
  void *IsOnConnectionQueueKey;
  
  // HTTP server configuration
  NSString *documentRoot;
  Class connectionClass;
  NSString *interface;
  UInt16 port;

  // Connection management
  NSMutableArray *connections;
  NSLock *connectionsLock;
  
  BOOL isRunning;
}

/**
 * Specifies the document root to serve files from.
 * For example, if you set this to "/Users/<your_username>/Sites",
 * then it will serve files out of the local Sites directory (including subdirectories).
 * 
 * The default value is nil.
 * The default server configuration will not serve any files until this is set.
 * 
 * If you change the documentRoot while the server is running,
 * the change will affect future incoming http connections.
 **/
- (NSString *)documentRoot;
- (void)setDocumentRoot:(NSString *)value;

/**
 * The connection class is the class used to handle incoming HTTP connections.
 * 
 * The default value is [HTTPConnection class].
 * You can override HTTPConnection, and then set this to [MyHTTPConnection class].
 * 
 * If you change the connectionClass while the server is running,
 * the change will affect future incoming http connections.
 **/
- (Class)connectionClass;
- (void)setConnectionClass:(Class)value;

/**
 * Set what interface you'd like the server to listen on.
 * By default this is nil, which causes the server to listen on all available interfaces like en1, wifi etc.
 * 
 * The interface may be specified by name (e.g. "en1" or "lo0") or by IP address (e.g. "192.168.4.34").
 * You may also use the special strings "localhost" or "loopback" to specify that
 * the socket only accept connections from the local machine.
 **/
- (NSString *)interface;
- (void)setInterface:(NSString *)value;

/**
 * The port number to run the HTTP server on.
 * 
 * The default port number is zero, meaning the server will automatically use any available port.
 * This is the recommended port value, as it avoids possible port conflicts with other applications.
 * Technologies such as Bonjour can be used to allow other applications to automatically discover the port number.
 * 
 * Note: As is common on most OS's, you need root privledges to bind to port numbers below 1024.
 * 
 * You can change the port property while the server is running, but it won't affect the running server.
 * To actually change the port the server is listening for connections on you'll need to restart the server.
 * 
 * The listeningPort method will always return the port number the running server is listening for connections on.
 * If the server is not running this method returns 0.
 **/
- (UInt16)port;
- (UInt16)listeningPort;
- (void)setPort:(UInt16)value;

/**
 * Attempts to starts the server on the configured port, interface, etc.
 * 
 * If an error occurs, this method returns NO and sets the errPtr (if given).
 * Otherwise returns YES on success.
 * 
 * Some examples of errors that might occur:
 * - You specified the server listen on a port which is already in use by another application.
 * - You specified the server listen on a port number below 1024, which requires root priviledges.
 * 
 * Code Example:
 * 
 * NSError *err = nil;
 * if (![httpServer start:&err])
 * {
 *     NSLog(@"Error starting http server: %@", err);
 * }
 **/
- (BOOL)start:(NSError **)errPtr;

/**
 * Stops the server, preventing it from accepting any new connections.
 * You may specify whether or not you want to close the existing client connections.
 * 
 * The default stop method (with no arguments) will close any existing connections. (It invokes [self stop:NO])
 **/
- (void)stop;
- (void)stop:(BOOL)keepExistingConnections;

- (BOOL)isRunning;

- (NSUInteger)numberOfHTTPConnections;

@end
