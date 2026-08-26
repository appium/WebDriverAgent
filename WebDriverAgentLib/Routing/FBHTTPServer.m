/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBHTTPServer.h"

#import "FBCommandStatus.h"
#import "FBConfiguration.h"
#import "FBResponsePayload.h"
#import "FBTCPSocket.h"

static NSData *FBCRLFCRLFData(void)
{
  static NSData *data;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    data = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
  });
  return data;
}

// -dataUsingEncoding:NSUTF8StringEncoding never actually returns nil; this just keeps the cast
// out of every call site below.
static NSData * _Nonnull FBUTF8Data(NSString *string)
{
  return (NSData * _Nonnull)[string dataUsingEncoding:NSUTF8StringEncoding];
}

// Upper bound for a request's header block (the bytes before \r\n\r\n). A connection that keeps
// sending bytes without ever completing its header block would otherwise grow its buffer without
// limit. Real WDA requests carry a handful of short headers; 64 KiB is far above anything
// legitimate.
static const NSUInteger FBMaxRequestHeaderSize = 64 * 1024;

// Strictly parses a Content-Length value: ASCII decimal digits only, bounded so the value below
// cannot overflow. Returns NO for anything else - -integerValue must not be used here, since it
// silently maps garbage ("bogus" -> 0, "12abc" -> 12) to a wrong body length, desyncing the
// framing of every subsequent request on the connection.
static BOOL FBParseContentLength(NSString *value, NSUInteger *outLength)
{
  // 15 digits keeps the value far below NSUIntegerMax on every platform; any real body length
  // that long is rejected by the body size limit anyway.
  if (value.length < 1 || value.length > 15) {
    return NO;
  }
  unsigned long long result = 0;
  for (NSUInteger i = 0; i < value.length; i++) {
    unichar c = [value characterAtIndex:i];
    if (c < '0' || c > '9') {
      return NO;
    }
    result = result * 10 + (c - '0');
  }
  *outLength = (NSUInteger)result;
  return YES;
}

@interface FBHTTPRoute : NSObject
@property (nonatomic, copy) NSString *verb;
@property (nonatomic, strong) NSRegularExpression *regex;
@property (nonatomic, copy, nullable) NSArray<NSString *> *keys;
@property (nonatomic, copy) void (^block)(RouteRequest *request, RouteResponse *response);
@property (nonatomic, assign) BOOL isStandalone;
@end

@implementation FBHTTPRoute
@end


// Cached result of parsing a connection's request line + headers, kept around while its body is
// still streaming in so a slow body doesn't cause the header block to be re-found and re-parsed
// on every single incoming TCP segment.
@interface FBPendingHTTPRequestHeader : NSObject
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *pathAndQuery;
@property (nonatomic) NSUInteger bodyStart;
@property (nonatomic) NSUInteger contentLength;
@end

@implementation FBPendingHTTPRequestHeader
@end


// One dispatched-but-not-yet-answered request. Default (pointer) identity, so two pipelined
// requests sharing a connection are never conflated into a single tracked entry.
@interface FBPendingRequest : NSObject
@property (nonatomic, strong, readonly) nw_connection_t client;
@end

@implementation FBPendingRequest

- (instancetype)initWithClient:(nw_connection_t)client
{
  if ((self = [super init])) {
    _client = client;
  }
  return self;
}

@end


@interface FBHTTPServer () <FBTCPSocketDelegate>

@property (nonatomic, nullable, strong) FBTCPSocket *socket;
@property (nonatomic, strong) NSMutableArray<FBHTTPRoute *> *routes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *defaultHeaders;
@property (nonatomic, nullable) dispatch_queue_t routeQueue;
@property (nonatomic, copy, nullable) NSString *interface;
// nw_connection_t isn't NSCopying, so it can't be an NSDictionary key - use NSMapTable instead.
@property (nonatomic, strong) NSMapTable<id, NSMutableData *> *connectionBuffers;
// Per-client cache of the already-parsed request line + headers while its body is still
// arriving; nil while a client's next unread bytes start with an unparsed header block.
@property (nonatomic, strong) NSMapTable<id, FBPendingHTTPRequestHeader *> *pendingRequestHeaders;
// All buffer access - appending new data and -processBufferForClient:'s unlocked parse - is
// funneled through this one serial queue, so appends can never race a parse.
@property (nonatomic, strong) dispatch_queue_t bufferProcessingQueue;
// Connections with a request parsed off the buffer but not yet answered. Blocks
// -processBufferForClient: from starting the next pipelined request, so responses on one
// connection can't be written out of order. Guarded by @synchronized(self.connectionBuffers).
@property (nonatomic, strong) NSMutableSet *connectionsAwaitingResponse;
// Keyed by "METHOD path" - requests waiting on an already in-flight standalone request for that
// endpoint. Guarded by @synchronized(self.standaloneWaiters).
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<FBPendingRequest *> *> *standaloneWaiters;
// Keyed by the "sessionID" path param - requests currently queued or executing for that session,
// standalone or not (except DELETE /session itself - see -dispatchMethod:). See
// -abandonPendingRequestsForSessionID:. Guarded by @synchronized(self.pendingSessionRequests).
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<FBPendingRequest *> *> *pendingSessionRequests;

@end

@implementation FBHTTPServer

- (instancetype)init
{
  if ((self = [super init])) {
    _routes = [NSMutableArray array];
    _defaultHeaders = [NSMutableDictionary dictionary];
    _connectionBuffers = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSMapTableObjectPointerPersonality | NSMapTableStrongMemory)
                                                 valueOptions:(NSPointerFunctionsOptions)NSMapTableStrongMemory];
    _pendingRequestHeaders = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSMapTableObjectPointerPersonality | NSMapTableStrongMemory)
                                                    valueOptions:(NSPointerFunctionsOptions)NSMapTableStrongMemory];
    _bufferProcessingQueue = dispatch_queue_create("com.facebook.wda.http.bufferProcessing", DISPATCH_QUEUE_SERIAL);
    _connectionsAwaitingResponse = [NSMutableSet set];
    _standaloneWaiters = [NSMutableDictionary dictionary];
    _pendingSessionRequests = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)setRouteQueue:(nullable dispatch_queue_t)queue
{
  _routeQueue = queue;
}

- (void)setDefaultHeader:(NSString *)field value:(NSString *)value
{
  self.defaultHeaders[field] = value;
}

- (void)setInterface:(nullable NSString *)interface
{
  _interface = interface.copy;
}

#pragma mark - Route registration

- (FBHTTPRoute *)compiledRouteWithPath:(NSString *)path
{
  FBHTTPRoute *route = [FBHTTPRoute new];
  NSMutableArray<NSString *> *keys = [NSMutableArray array];

  // Escape regex-significant characters before substituting :param placeholders.
  NSRegularExpression *escapeRegex = [NSRegularExpression regularExpressionWithPattern:@"[.+()]"
                                                                                options:(NSRegularExpressionOptions)0
                                                                                  error:nil];
  NSString *escapedPath = [escapeRegex stringByReplacingMatchesInString:path
                                                                  options:(NSMatchingOptions)0
                                                                    range:NSMakeRange(0, path.length)
                                                             withTemplate:@"\\\\$0"];

  NSRegularExpression *paramRegex = [NSRegularExpression regularExpressionWithPattern:@"(:(\\w+)|\\*)"
                                                                               options:(NSRegularExpressionOptions)0
                                                                                 error:nil];
  NSMutableString *regexPath = [NSMutableString stringWithString:escapedPath];
  __block NSInteger diff = 0;
  __block NSUInteger wildcardIndex = 0;
  [paramRegex enumerateMatchesInString:escapedPath
                                options:(NSMatchingOptions)0
                                  range:NSMakeRange(0, escapedPath.length)
                             usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
    NSRange replacementRange = NSMakeRange(diff + result.range.location, result.range.length);
    NSString *capturedString = [escapedPath substringWithRange:result.range];
    NSString *replacementString;
    if ([capturedString isEqualToString:@"*"]) {
      // Only the first wildcard keeps the plain "wildcards" name - later ones get an index
      // suffix so multiple "*" segments in one path don't overwrite each other's capture.
      NSString *wildcardKey = 0 == wildcardIndex ? @"wildcards" : [NSString stringWithFormat:@"wildcards%lu", (unsigned long)wildcardIndex];
      wildcardIndex++;
      [keys addObject:wildcardKey];
      replacementString = @"(.*?)";
    } else {
      NSString *keyString = [escapedPath substringWithRange:[result rangeAtIndex:2]];
      [keys addObject:keyString];
      replacementString = @"([^/]+)";
    }
    [regexPath replaceCharactersInRange:replacementRange withString:replacementString];
    diff += replacementString.length - result.range.length;
  }];

  NSString *anchoredPattern = [NSString stringWithFormat:@"^%@$", regexPath];
  route.regex = [NSRegularExpression regularExpressionWithPattern:anchoredPattern
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
  route.keys = keys.count > 0 ? keys.copy : nil;
  return route;
}

- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
               block:(void (^)(RouteRequest *request, RouteResponse *response))block
{
  [self handleMethod:method withPath:path standalone:NO block:block];
}

- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
          standalone:(BOOL)standalone
               block:(void (^)(RouteRequest *request, RouteResponse *response))block
{
  FBHTTPRoute *route = [self compiledRouteWithPath:path];
  route.verb = method.uppercaseString;
  route.block = block;
  route.isStandalone = standalone;
  [self.routes addObject:route];
}

- (void)get:(NSString *)path withBlock:(void (^)(RouteRequest *request, RouteResponse *response))block
{
  [self handleMethod:@"GET" withPath:path block:block];
}

#pragma mark - Lifecycle

- (BOOL)start:(NSError **)error
{
  FBTCPSocket *socket = [[FBTCPSocket alloc] initWithPort:self.port];
  socket.interface = self.interface;
  socket.delegate = self;
  if (![socket startWithError:error]) {
    return NO;
  }
  self.socket = socket;
  _isRunning = YES;
  return YES;
}

- (void)stop:(BOOL)immediately
{
  [self.socket stop];
  self.socket = nil;
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeAllObjects];
    [self.pendingRequestHeaders removeAllObjects];
    [self.connectionsAwaitingResponse removeAllObjects];
  }
  _isRunning = NO;
}

#pragma mark - FBTCPSocketDelegate

- (void)didClientConnect:(nw_connection_t)newClient
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers setObject:[NSMutableData data] forKey:newClient];
  }
}

- (void)didClientDisconnect:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
    [self.pendingRequestHeaders removeObjectForKey:client];
    [self.connectionsAwaitingResponse removeObject:client];
  }
}

- (void)client:(nw_connection_t)client didReceiveData:(NSData *)data
{
  // The append itself, not just the parse, must run on bufferProcessingQueue: otherwise a receive
  // callback here could still mutate the buffer while -processBufferForClient: is reading it
  // unlocked on that queue.
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.bufferProcessingQueue, ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (nil == strongSelf) {
      return;
    }
    @synchronized (strongSelf.connectionBuffers) {
      NSMutableData *buffer = [strongSelf.connectionBuffers objectForKey:client];
      if (nil == buffer) {
        return;
      }
      [buffer appendData:data];
    }
    [strongSelf processBufferForClient:client];
  });
}

#pragma mark - HTTP parsing

// Parses and dispatches at most one request per call; a connection with one already in flight is
// left alone (see -connectionsAwaitingResponse) until its response is written.
- (void)processBufferForClient:(nw_connection_t)client
{
  NSMutableData *buffer;
  FBPendingHTTPRequestHeader *pending;
  @synchronized (self.connectionBuffers) {
    if ([self.connectionsAwaitingResponse containsObject:client]) {
      return;
    }
    buffer = [self.connectionBuffers objectForKey:client];
    if (nil == buffer) {
      return;
    }
    pending = [self.pendingRequestHeaders objectForKey:client];
  }

  if (nil == pending) {
    NSRange headerEndRange = [buffer rangeOfData:FBCRLFCRLFData() options:(NSDataSearchOptions)0 range:NSMakeRange(0, buffer.length)];
    if (NSNotFound == headerEndRange.location) {
      if (buffer.length > FBMaxRequestHeaderSize) {
        // The client has sent more than any legitimate header block could occupy without ever
        // completing it - stop buffering and drop the connection instead of growing without bound.
        [self respondBadRequestToClient:client];
        return;
      }
      // Wait for the rest of the header block to arrive.
      return;
    }

    NSData *headerData = [buffer subdataWithRange:NSMakeRange(0, headerEndRange.location)];
    NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [headerString componentsSeparatedByString:@"\r\n"];
    if (lines.count < 1) {
      [self respondBadRequestToClient:client];
      return;
    }

    NSArray<NSString *> *requestLineParts = [lines.firstObject componentsSeparatedByString:@" "];
    if (requestLineParts.count < 2) {
      [self respondBadRequestToClient:client];
      return;
    }

    NSMutableDictionary<NSString *, NSString *> *requestHeaders = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lines.count; i++) {
      NSString *line = lines[i];
      NSRange colonRange = [line rangeOfString:@":"];
      if (NSNotFound == colonRange.location) {
        continue;
      }
      NSString *name = [line substringToIndex:colonRange.location];
      NSString *value = [[line substringFromIndex:colonRange.location + 1]
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
      requestHeaders[name.lowercaseString] = value;
    }

    NSString *transferEncoding = requestHeaders[@"transfer-encoding"];
    if (transferEncoding.length > 0) {
      // No transfer decoder is implemented at all, so any encoding (chunked or otherwise -
      // including a value only introduced by a duplicate header overwriting "chunked" above)
      // is rejected rather than risking the body being misread as empty and desyncing the rest
      // of the connection's request stream.
      RouteResponse *notImplemented = [RouteResponse new];
      id<FBResponsePayload> notImplementedPayload = FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Transfer-Encoding is not supported"
                                                                                                                  traceback:nil]);
      [notImplementedPayload dispatchWithResponse:notImplemented];
      [self failClient:client withResponse:notImplemented];
      return;
    }

    NSString *contentLengthValue = requestHeaders[@"content-length"];
    NSUInteger contentLength = 0;
    if (nil != contentLengthValue && !FBParseContentLength(contentLengthValue, &contentLength)) {
      // With an unparseable Content-Length the body's extent is unknowable, so the connection
      // cannot be resynced - reject and close.
      [self respondBadRequestToClient:client];
      return;
    }
    if (contentLength > FBConfiguration.sharedInstance.httpRequestBodySizeLimit) {
      // Closes the connection after responding, since the rest of the oversized body is still incoming.
      RouteResponse *tooLarge = [RouteResponse new];
      id<FBResponsePayload> tooLargePayload = FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request body exceeds the configured size limit"
                                                                                                            traceback:nil]);
      [tooLargePayload dispatchWithResponse:tooLarge];
      [self failClient:client withResponse:tooLarge];
      return;
    }

    pending = [FBPendingHTTPRequestHeader new];
    pending.method = requestLineParts[0].uppercaseString;
    pending.pathAndQuery = requestLineParts[1];
    pending.bodyStart = headerEndRange.location + headerEndRange.length;
    pending.contentLength = contentLength;
    @synchronized (self.connectionBuffers) {
      [self.pendingRequestHeaders setObject:pending forKey:client];
    }
  }

  NSUInteger totalRequestLength = pending.bodyStart + pending.contentLength;
  if (buffer.length < totalRequestLength) {
    // Wait for the rest of the body to arrive - the parsed header stays cached above, so this
    // doesn't re-scan/re-parse the header block on every subsequently arriving chunk.
    return;
  }

  NSData *body = pending.contentLength > 0 ? [buffer subdataWithRange:NSMakeRange(pending.bodyStart, pending.contentLength)] : [NSData data];

  @synchronized (self.connectionBuffers) {
    [buffer replaceBytesInRange:NSMakeRange(0, totalRequestLength) withBytes:NULL length:0];
    [self.pendingRequestHeaders removeObjectForKey:client];
    [self.connectionsAwaitingResponse addObject:client];
  }

  [self dispatchMethod:pending.method pathAndQuery:pending.pathAndQuery body:body client:client];
}

// Removes the client's buffered state and responds with a closing error response. Removing the
// buffer synchronously ensures any request bytes still streaming in for this connection are
// dropped rather than being re-parsed and re-triggering this same response.
- (void)failClient:(nw_connection_t)client withResponse:(RouteResponse *)response
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
    [self.pendingRequestHeaders removeObjectForKey:client];
  }
  [self applyDefaultHeadersToResponse:response];
  [self writeResponse:response toClient:client thenCloseConnection:YES];
}

- (void)respondBadRequestToClient:(nw_connection_t)client
{
  RouteResponse *badRequest = [RouteResponse new];
  id<FBResponsePayload> payload = FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request could not be parsed as valid HTTP"
                                                                                                traceback:nil]);
  [payload dispatchWithResponse:badRequest];
  [self failClient:client withResponse:badRequest];
}

- (void)applyDefaultHeadersToResponse:(RouteResponse *)response
{
  [self.defaultHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
    [response setHeader:field value:value];
  }];
}

- (void)dispatchMethod:(NSString *)method pathAndQuery:(NSString *)pathAndQuery body:(NSData *)body client:(nw_connection_t)client
{
  NSURLComponents *requestTarget = [NSURLComponents componentsWithString:pathAndQuery];
  NSString *path = requestTarget.path ?: pathAndQuery;

  for (FBHTTPRoute *route in self.routes) {
    if (![route.verb isEqualToString:method]) {
      continue;
    }
    NSTextCheckingResult *result = [route.regex firstMatchInString:path options:(NSMatchingOptions)0 range:NSMakeRange(0, path.length)];
    if (nil == result) {
      continue;
    }

    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *queryItem in requestTarget.queryItems) {
      params[queryItem.name] = queryItem.value ?: @"";
    }
    if (route.keys.count > 0 && result.numberOfRanges == route.keys.count + 1) {
      NSUInteger index = 1;
      for (NSString *key in route.keys) {
        params[key] = [path substringWithRange:[result rangeAtIndex:index]];
        index++;
      }
    }

    NSURL *url = [NSURL URLWithString:path] ?: [NSURL URLWithString:@"/"];
    RouteRequest *request = [[RouteRequest alloc] initWithURL:url params:params.copy body:body];
    RouteResponse *response = [RouteResponse new];
    [self applyDefaultHeadersToResponse:response];

    NSString *sessionID = params[@"sessionID"];
    if (route.isStandalone) {
      // DELETE triggers -abandonPendingRequestsForSessionID: itself; tracking its own request
      // would make it abandon itself and write a response twice.
      NSString *trackedSessionID = [route.verb isEqualToString:@"DELETE"] ? nil : sessionID;
      [self dispatchStandaloneRoute:route request:request response:response client:client method:method pathAndQuery:pathAndQuery sessionID:trackedSessionID];
      return;
    }

    FBPendingRequest *pendingRequest = nil;
    if (nil != sessionID) {
      pendingRequest = [[FBPendingRequest alloc] initWithClient:client];
      [self trackPendingRequest:pendingRequest forSessionID:sessionID];
    }

    void (^invoke)(void) = ^{
      route.block(request, response);
      // Whoever untracks `pendingRequest` first "wins" and gets to respond - either this normal
      // completion, or -abandonPendingRequestsForSessionID: on another thread.
      BOOL shouldRespond = (nil == pendingRequest) || [self untrackPendingRequest:pendingRequest forSessionID:sessionID];
      if (shouldRespond) {
        [self writeResponse:response toClient:client];
      }
    };
    dispatch_queue_t routeQueue = self.routeQueue;
    if (routeQueue) {
      dispatch_async((dispatch_queue_t _Nonnull)routeQueue, invoke);
    } else {
      invoke();
    }
    return;
  }

  RouteResponse *notFound = [RouteResponse new];
  FBCommandStatus *status = [FBCommandStatus unknownCommandErrorWithMessage:nil
                                                                   traceback:nil];
  [FBResponseWithStatus(status) dispatchWithResponse:notFound];
  [self applyDefaultHeadersToResponse:notFound];
  [self writeResponse:notFound toClient:client];
}

#pragma mark - Session-scoped request cancellation

- (void)trackPendingRequest:(FBPendingRequest *)pendingRequest forSessionID:(NSString *)sessionID
{
  @synchronized (self.pendingSessionRequests) {
    NSMutableSet<FBPendingRequest *> *pendingRequests = self.pendingSessionRequests[sessionID];
    if (nil == pendingRequests) {
      pendingRequests = [NSMutableSet set];
      self.pendingSessionRequests[sessionID] = pendingRequests;
    }
    [pendingRequests addObject:pendingRequest];
  }
}

// Returns YES if this caller won the race to respond, vs. -abandonPendingRequestsForSessionID:
// already having claimed `pendingRequest` on another thread.
- (BOOL)untrackPendingRequest:(FBPendingRequest *)pendingRequest forSessionID:(NSString *)sessionID
{
  @synchronized (self.pendingSessionRequests) {
    NSMutableSet<FBPendingRequest *> *pendingRequests = self.pendingSessionRequests[sessionID];
    BOOL wasPending = [pendingRequests containsObject:pendingRequest];
    if (wasPending) {
      [pendingRequests removeObject:pendingRequest];
      if (0 == pendingRequests.count) {
        [self.pendingSessionRequests removeObjectForKey:sessionID];
      }
    }
    return wasPending;
  }
}

- (void)abandonPendingRequestsForSessionID:(NSString *)sessionID withResponse:(RouteResponse *)response
{
  NSSet<FBPendingRequest *> *pendingRequests;
  @synchronized (self.pendingSessionRequests) {
    pendingRequests = [self.pendingSessionRequests[sessionID] copy];
    [self.pendingSessionRequests removeObjectForKey:sessionID];
  }
  for (FBPendingRequest *pendingRequest in pendingRequests) {
    [self writeResponse:response toClient:pendingRequest.client];
  }
}

#pragma mark - Standalone route dispatch

- (void)dispatchStandaloneRoute:(FBHTTPRoute *)route
                         request:(RouteRequest *)request
                        response:(RouteResponse *)response
                          client:(nw_connection_t)client
                          method:(NSString *)method
                    pathAndQuery:(NSString *)pathAndQuery
                       sessionID:(nullable NSString *)sessionID
{
  // Includes the query string so requests with different params are never coalesced together.
  NSString *key = [NSString stringWithFormat:@"%@ %@", method, pathAndQuery];
  FBPendingRequest *waiter = [[FBPendingRequest alloc] initWithClient:client];
  if (nil != sessionID) {
    [self trackPendingRequest:waiter forSessionID:sessionID];
  }

  BOOL isInFlight = NO;
  @synchronized (self.standaloneWaiters) {
    NSMutableArray<FBPendingRequest *> *waiters = self.standaloneWaiters[key];
    if (nil != waiters) {
      [waiters addObject:waiter];
      isInFlight = YES;
    } else {
      self.standaloneWaiters[key] = [NSMutableArray array];
    }
  }
  if (isInFlight) {
    // An identical request is already executing; it will deliver this connection's response too.
    return;
  }

  dispatch_queue_t queue = dispatch_queue_create(key.UTF8String, DISPATCH_QUEUE_SERIAL);
  __weak typeof(self) weakSelf = self;
  dispatch_async(queue, ^{
    route.block(request, response);
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (nil == strongSelf) {
      return;
    }
    NSArray<FBPendingRequest *> *joinedWaiters;
    @synchronized (strongSelf.standaloneWaiters) {
      joinedWaiters = [strongSelf.standaloneWaiters[key] copy];
      [strongSelf.standaloneWaiters removeObjectForKey:key];
    }
    for (FBPendingRequest *joinedWaiter in [@[waiter] arrayByAddingObjectsFromArray:joinedWaiters]) {
      BOOL shouldRespond = (nil == sessionID) || [strongSelf untrackPendingRequest:joinedWaiter forSessionID:sessionID];
      if (shouldRespond) {
        [strongSelf writeResponse:response toClient:joinedWaiter.client];
      }
    }
  });
}

- (void)writeResponse:(RouteResponse *)response toClient:(nw_connection_t)client
{
  [self writeResponse:response toClient:client thenCloseConnection:NO];
}

- (void)writeResponse:(RouteResponse *)response toClient:(nw_connection_t)client thenCloseConnection:(BOOL)shouldClose
{
  NSMutableData *payload = [NSMutableData data];
  NSString *statusLine = [NSString stringWithFormat:@"HTTP/1.1 %ld %@\r\n",
                           (long)response.statusCode, [self reasonPhraseForStatusCode:response.statusCode]];
  [payload appendData:FBUTF8Data(statusLine)];

  NSData *body = response.responseData ?: [NSData data];
  NSMutableDictionary<NSString *, NSString *> *headers = response.headers.mutableCopy;
  if (nil == headers[@"Content-Length"]) {
    headers[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
  }
  [headers enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
    NSString *headerLine = [NSString stringWithFormat:@"%@: %@\r\n", field, value];
    [payload appendData:FBUTF8Data(headerLine)];
  }];
  [payload appendData:FBUTF8Data(@"\r\n")];
  [payload appendData:body];

  if (shouldClose) {
    __weak typeof(self) weakSelf = self;
    [self.socket writeData:payload toClient:client completion:^{
      [weakSelf closeClient:client];
    }];
  } else {
    // Sent before unblocking the next pipelined request, so responses can't reach the wire out of order.
    [self.socket writeData:payload toClient:client];
    @synchronized (self.connectionBuffers) {
      [self.connectionsAwaitingResponse removeObject:client];
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.bufferProcessingQueue, ^{
      [weakSelf processBufferForClient:client];
    });
  }
}

- (void)closeClient:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
    [self.connectionsAwaitingResponse removeObject:client];
  }
  nw_connection_cancel(client);
}

- (NSString *)reasonPhraseForStatusCode:(HTTPStatusCode)statusCode
{
  // if/else, not switch, to avoid having to list all ~90 HTTPStatusCode cases for -Wswitch-enum.
  if (kHTTPStatusCodeOK == statusCode) {
    return @"OK";
  } else if (kHTTPStatusCodeBadRequest == statusCode) {
    return @"Bad Request";
  } else if (kHTTPStatusCodeNotFound == statusCode) {
    return @"Not Found";
  } else if (kHTTPStatusCodeMethodNotAllowed == statusCode) {
    return @"Method Not Allowed";
  } else if (kHTTPStatusCodeRequestTimeout == statusCode) {
    return @"Request Timeout";
  } else if (kHTTPStatusCodeRequestEntityTooLarge == statusCode) {
    return @"Request Entity Too Large";
  } else if (kHTTPStatusCodeNotImplemented == statusCode) {
    return @"Not Implemented";
  } else if (kHTTPStatusCodeInternalServerError == statusCode) {
    return @"Internal Server Error";
  }
  return @"Status";
}

@end
