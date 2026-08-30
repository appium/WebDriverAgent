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
#import "FBLogger.h"
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

// Caps a request's header block, so a connection that never completes one cannot grow its buffer
// without limit. Matches node's default --max-http-header-size.
static const NSUInteger FBMaxRequestHeaderSize = 16 * 1024;

// ASCII decimal digits only. -integerValue must not be used here: it maps garbage silently
// ("bogus" -> 0, "12abc" -> 12), desyncing the framing of every later request on the connection.
static BOOL FBParseContentLength(NSString *value, NSUInteger *outLength)
{
  if (value.length < 1) {
    return NO;
  }
  NSUInteger result = 0;
  for (NSUInteger i = 0; i < value.length; i++) {
    unichar c = [value characterAtIndex:i];
    if (c < '0' || c > '9') {
      return NO;
    }
    NSUInteger digit = (NSUInteger)(c - '0');
    // NSUInteger is 32-bit on watchOS (arm64_32), so this bounds truncation as well as overflow.
    // Anything smaller is left to the caller's httpRequestBodySizeLimit check.
    if (result > (NSUIntegerMax - digit) / 10) {
      return NO;
    }
    result = result * 10 + digit;
  }
  *outLength = result;
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
// Already-abandoned sessions mapped to the response they were abandoned with, so a request parsed
// after that point is answered at once instead of queueing for a session that is gone. Kept for
// the server's lifetime; ids are UUIDs. Guarded by @synchronized(self.pendingSessionRequests).
@property (nonatomic, strong) NSMutableDictionary<NSString *, RouteResponse *> *abandonedSessionResponses;
// When each connection started waiting for its current request. The reaper closes connections
// whose entry outlives FBIncompleteRequestTimeout; idle keep-alive connections have no entry and
// are exempt. Guarded by @synchronized(self.connectionBuffers).
@property (nonatomic, strong) NSMapTable<id, NSDate *> *incompleteRequestStarts;
@property (nonatomic, nullable) dispatch_source_t staleConnectionReaper;

@end

// How long a connection may take to deliver a complete request, matching the header read timeout
// the previous CocoaHTTPServer stack enforced.
static const NSTimeInterval FBIncompleteRequestTimeout = 30.0;
static const int64_t FBStaleConnectionSweepIntervalSec = 10;

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
    _abandonedSessionResponses = [NSMutableDictionary dictionary];
    _incompleteRequestStarts = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSMapTableObjectPointerPersonality | NSMapTableStrongMemory)
                                                     valueOptions:(NSPointerFunctionsOptions)NSMapTableStrongMemory];
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
  dispatch_source_t reaper = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.bufferProcessingQueue);
  dispatch_source_set_timer(reaper,
                            dispatch_time(DISPATCH_TIME_NOW, FBStaleConnectionSweepIntervalSec * NSEC_PER_SEC),
                            (uint64_t)FBStaleConnectionSweepIntervalSec * NSEC_PER_SEC,
                            NSEC_PER_SEC);
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(reaper, ^{
    [weakSelf reapStaleConnections];
  });
  dispatch_resume(reaper);
  self.staleConnectionReaper = reaper;
  _isRunning = YES;
  return YES;
}

- (void)reapStaleConnections
{
  NSMutableArray *staleConnections = [NSMutableArray array];
  @synchronized (self.connectionBuffers) {
    for (id connection in self.incompleteRequestStarts) {
      // Waiting on the handler, not the peer - never reap, however long the handler takes.
      if ([self.connectionsAwaitingResponse containsObject:connection]) {
        continue;
      }
      NSDate *start = [self.incompleteRequestStarts objectForKey:connection];
      if (nil != start && -start.timeIntervalSinceNow > FBIncompleteRequestTimeout) {
        [staleConnections addObject:connection];
      }
    }
  }
  for (id connection in staleConnections) {
    [FBLogger logFmt:@"Closing a connection that did not deliver a complete request within %@ seconds", @(FBIncompleteRequestTimeout)];
    [self closeClient:(nw_connection_t)connection];
  }
}

- (void)stop:(BOOL)immediately
{
  dispatch_source_t reaper = self.staleConnectionReaper;
  if (nil != reaper) {
    dispatch_source_cancel(reaper);
    self.staleConnectionReaper = nil;
  }
  [self.socket stop];
  self.socket = nil;
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeAllObjects];
    [self.pendingRequestHeaders removeAllObjects];
    [self.connectionsAwaitingResponse removeAllObjects];
    [self.incompleteRequestStarts removeAllObjects];
  }
  _isRunning = NO;
}

#pragma mark - FBTCPSocketDelegate

- (void)didClientConnect:(nw_connection_t)newClient
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers setObject:[NSMutableData data] forKey:newClient];
    // Starts at connect, so a peer that connects and then sends nothing is reaped too.
    [self.incompleteRequestStarts setObject:[NSDate date] forKey:newClient];
  }
}

- (void)didClientDisconnect:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
    [self.pendingRequestHeaders removeObjectForKey:client];
    [self.connectionsAwaitingResponse removeObject:client];
    [self.incompleteRequestStarts removeObjectForKey:client];
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
    BOOL isOverBufferCap = NO;
    @synchronized (strongSelf.connectionBuffers) {
      NSMutableData *buffer = [strongSelf.connectionBuffers objectForKey:client];
      if (nil == buffer) {
        return;
      }
      [buffer appendData:data];
      // One maximal header block plus one maximal body, plus headroom for a pipelined follow-up.
      // The per-request checks don't run while a request is executing, so without this cap a
      // client could pump data unboundedly for as long as its previous request takes.
      uint64_t bufferCap = FBConfiguration.sharedInstance.httpRequestBodySizeLimit + 2 * (uint64_t)FBMaxRequestHeaderSize;
      if (bufferCap < FBConfiguration.sharedInstance.httpRequestBodySizeLimit) {
        bufferCap = UINT64_MAX;
      }
      isOverBufferCap = buffer.length > bufferCap;
      // In the body phase the timeout is an idle bound, refreshed on progress: a declared body
      // may legitimately be slow and its size is already capped by Content-Length. In the header
      // phase the clock is only started, never refreshed, so drip-fed headers cannot outlive it.
      BOOL isBodyPhase = nil != [strongSelf.pendingRequestHeaders objectForKey:client];
      if (isBodyPhase || nil == [strongSelf.incompleteRequestStarts objectForKey:client]) {
        [strongSelf.incompleteRequestStarts setObject:[NSDate date] forKey:client];
      }
    }
    if (isOverBufferCap) {
      // No response owed: a peer this far past any legitimate size is not reading anyway.
      [FBLogger log:@"Closing a connection that overflowed its request buffer"];
      [strongSelf closeClient:client];
      return;
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
    pending = [self parsedRequestHeaderFromBuffer:buffer forClient:client];
    if (nil == pending) {
      // Either the header block is still incomplete, or it was rejected and answered already.
      return;
    }
    @synchronized (self.connectionBuffers) {
      [self.pendingRequestHeaders setObject:pending forKey:client];
    }
  }

  [self dispatchBufferedRequestWithHeader:pending fromBuffer:buffer forClient:client];
}

// Locates the CRLFCRLF that ends the buffered header block and bounds the block's size. Returns
// NO when nothing can be parsed yet - either because more bytes are needed or because the block
// was rejected, in which case the 400 has already been written.
- (BOOL)findHeaderBlockEnd:(out NSRange *)outHeaderEndRange
                  inBuffer:(NSMutableData *)buffer
                 forClient:(nw_connection_t)client
{
  NSRange headerEndRange = [buffer rangeOfData:FBCRLFCRLFData() options:(NSDataSearchOptions)0 range:NSMakeRange(0, buffer.length)];
  if (NSNotFound == headerEndRange.location) {
    if (buffer.length > FBMaxRequestHeaderSize) {
      // Past any legitimate header block and still unterminated - stop buffering.
      [self respondBadRequestToClient:client];
    }
    // Otherwise wait for the rest of the header block to arrive.
    return NO;
  }
  if (headerEndRange.location > FBMaxRequestHeaderSize) {
    // The check above only fires while the terminator is missing; one large receive can deliver
    // an oversized block with it, so bound the completed block too before parsing it.
    [self respondBadRequestToClient:client];
    return NO;
  }
  *outHeaderEndRange = headerEndRange;
  return YES;
}

// Turns the header lines that follow the request line into a lowercase-keyed dictionary.
// Returns nil for the malformed and ambiguous shapes, having written the 400 already.
- (nullable NSDictionary<NSString *, NSString *> *)parsedHeaderFieldsFromLines:(NSArray<NSString *> *)lines
                                                                    forClient:(nw_connection_t)client
{
  NSMutableDictionary<NSString *, NSString *> *requestHeaders = [NSMutableDictionary dictionary];
  for (NSUInteger i = 1; i < lines.count; i++) {
    NSString *line = lines[i];
    NSRange colonRange = [line rangeOfString:@":"];
    if (0 == line.length) {
      continue;
    }
    if (NSNotFound == colonRange.location) {
      // Malformed. Skipping it would drop what it meant to say: "Content-Length 5" would
      // dispatch with an empty body, leaving its bytes to be parsed as another request.
      [self respondBadRequestToClient:client];
      return nil;
    }
    NSString *name = [line substringToIndex:colonRange.location];
    // RFC 7230 (3.2.4): whitespace before the colon MUST be rejected. Storing "content-length "
    // as its own key would drop the real header and desync the framing.
    if (0 == name.length
        || NSNotFound != [name rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location) {
      [self respondBadRequestToClient:client];
      return nil;
    }
    NSString *value = [[line substringFromIndex:colonRange.location + 1]
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *normalizedName = name.lowercaseString;
    // RFC 7230 (3.3.3): repeated framing fields are unrecoverable. Last-wins would let an empty
    // "Transfer-Encoding:" mask an earlier "chunked", and the last Content-Length drive parsing.
    if (([normalizedName isEqualToString:@"content-length"] || [normalizedName isEqualToString:@"transfer-encoding"])
        && nil != requestHeaders[normalizedName]) {
      [self respondBadRequestToClient:client];
      return nil;
    }
    requestHeaders[normalizedName] = value;
  }
  return requestHeaders;
}

// Rejects framing this server cannot honour and resolves the declared body length from the
// remaining framing headers. Returns NO having written the closing error response already.
- (BOOL)resolveBodyLength:(out NSUInteger *)outBodyLength
         fromHeaderFields:(NSDictionary<NSString *, NSString *> *)requestHeaders
                forClient:(nw_connection_t)client
{
  NSString *transferEncoding = requestHeaders[@"transfer-encoding"];
  if (nil != transferEncoding) {
    // No transfer decoder exists, so mere presence is rejected - including an empty value,
    // which is not a valid encoding list and would let the body be misread as empty.
    RouteResponse *notImplemented = [RouteResponse new];
    id<FBResponsePayload> notImplementedPayload = FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Transfer-Encoding is not supported"
                                                                                                                traceback:nil]);
    [notImplementedPayload dispatchWithResponse:notImplemented];
    [self failClient:client withResponse:notImplemented];
    return NO;
  }

  NSString *contentLengthValue = requestHeaders[@"content-length"];
  NSUInteger contentLength = 0;
  if (nil != contentLengthValue && !FBParseContentLength(contentLengthValue, &contentLength)) {
    // The body's extent is unknowable, so the connection cannot be resynced - reject and close.
    [self respondBadRequestToClient:client];
    return NO;
  }
  if (contentLength > FBConfiguration.sharedInstance.httpRequestBodySizeLimit) {
    // Closes the connection after responding, since the rest of the oversized body is still incoming.
    RouteResponse *tooLarge = [RouteResponse new];
    id<FBResponsePayload> tooLargePayload = FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request body exceeds the configured size limit"
                                                                                                          traceback:nil]);
    [tooLargePayload dispatchWithResponse:tooLarge];
    [self failClient:client withResponse:tooLarge];
    return NO;
  }
  *outBodyLength = contentLength;
  return YES;
}

// Parses the request line and headers of the request at the head of the buffer. Returns nil
// while the header block is still incomplete, and for a rejected one, which is answered here.
- (nullable FBPendingHTTPRequestHeader *)parsedRequestHeaderFromBuffer:(NSMutableData *)buffer
                                                             forClient:(nw_connection_t)client
{
  NSRange headerEndRange;
  if (![self findHeaderBlockEnd:&headerEndRange inBuffer:buffer forClient:client]) {
    return nil;
  }

  NSData *headerData = [buffer subdataWithRange:NSMakeRange(0, headerEndRange.location)];
  NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
  NSArray<NSString *> *lines = [headerString componentsSeparatedByString:@"\r\n"];
  if (lines.count < 1) {
    [self respondBadRequestToClient:client];
    return nil;
  }

  NSArray<NSString *> *requestLineParts = [lines.firstObject componentsSeparatedByString:@" "];
  if (requestLineParts.count < 2) {
    [self respondBadRequestToClient:client];
    return nil;
  }

  NSDictionary<NSString *, NSString *> *requestHeaders = [self parsedHeaderFieldsFromLines:lines forClient:client];
  if (nil == requestHeaders) {
    return nil;
  }
  NSUInteger contentLength = 0;
  if (![self resolveBodyLength:&contentLength fromHeaderFields:requestHeaders forClient:client]) {
    return nil;
  }

  FBPendingHTTPRequestHeader *pending = [FBPendingHTTPRequestHeader new];
  pending.method = requestLineParts[0].uppercaseString;
  pending.pathAndQuery = requestLineParts[1];
  pending.bodyStart = headerEndRange.location + headerEndRange.length;
  pending.contentLength = contentLength;
  return pending;
}

// Consumes the already-parsed request from the head of the buffer and dispatches it, once its
// whole body has arrived. Returns with the cached header left in place while it hasn't.
- (void)dispatchBufferedRequestWithHeader:(FBPendingHTTPRequestHeader *)pending
                               fromBuffer:(NSMutableData *)buffer
                                forClient:(nw_connection_t)client
{
  NSUInteger totalRequestLength = pending.bodyStart + pending.contentLength;
  if (buffer.length < totalRequestLength) {
    // Wait for the rest of the body to arrive - the parsed header stays cached, so this
    // doesn't re-scan/re-parse the header block on every subsequently arriving chunk.
    @synchronized (self.connectionBuffers) {
      // The request is now in its body phase, which is idle-bounded rather than hard-bounded.
      // -client:didReceiveData: samples that phase before this parse runs, so the receive that
      // completed a slowly-delivered header (and carried the first body bytes) would otherwise
      // leave the connection on its header-phase timestamp and let the sweep close it despite
      // the body having just made progress.
      [self.incompleteRequestStarts setObject:[NSDate date] forKey:client];
    }
    return;
  }

  NSData *body = pending.contentLength > 0 ? [buffer subdataWithRange:NSMakeRange(pending.bodyStart, pending.contentLength)] : [NSData data];

  @synchronized (self.connectionBuffers) {
    [buffer replaceBytesInRange:NSMakeRange(0, totalRequestLength) withBytes:NULL length:0];
    [self.pendingRequestHeaders removeObjectForKey:client];
    [self.connectionsAwaitingResponse addObject:client];
    if (0 == buffer.length) {
      // A complete request was delivered and nothing further is buffered: the connection is a
      // healthy keep-alive and must not be reaped while idle.
      [self.incompleteRequestStarts removeObjectForKey:client];
    } else {
      // Pipelined bytes of the next request are already buffered - restart its clock.
      [self.incompleteRequestStarts setObject:[NSDate date] forKey:client];
    }
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
      RouteResponse *abandonedResponse = [self trackPendingRequest:pendingRequest forSessionID:sessionID];
      if (nil != abandonedResponse) {
        [self writeResponse:abandonedResponse toClient:client];
        return;
      }
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

// Returns nil once `pendingRequest` is tracked, or the response an already-abandoned session was
// abandoned with, which the caller must deliver instead of dispatching.
- (nullable RouteResponse *)trackPendingRequest:(FBPendingRequest *)pendingRequest forSessionID:(NSString *)sessionID
{
  @synchronized (self.pendingSessionRequests) {
    RouteResponse *abandonedResponse = self.abandonedSessionResponses[sessionID];
    if (nil != abandonedResponse) {
      return abandonedResponse;
    }
    NSMutableSet<FBPendingRequest *> *pendingRequests = self.pendingSessionRequests[sessionID];
    if (nil == pendingRequests) {
      pendingRequests = [NSMutableSet set];
      self.pendingSessionRequests[sessionID] = pendingRequests;
    }
    [pendingRequests addObject:pendingRequest];
    return nil;
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
    // Recorded before the lock is dropped, so requests admitted from here on are rejected.
    self.abandonedSessionResponses[sessionID] = response;
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
    RouteResponse *abandonedResponse = [self trackPendingRequest:waiter forSessionID:sessionID];
    if (nil != abandonedResponse) {
      [self writeResponse:abandonedResponse toClient:client];
      return;
    }
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
    [self.socket writeData:payload toClient:client completion:^(BOOL didSucceed) {
      [weakSelf closeClient:client];
    }];
  } else {
    // Unblocked from the send's completion, not before it: ordering is preserved either way
    // (nw_connection_send is FIFO per connection), but unblocking early lets a client that
    // pipelines without reading responses pile up rendered responses inside Network.framework.
    __weak typeof(self) weakSelf = self;
    [self.socket writeData:payload toClient:client completion:^(BOOL didSucceed) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (nil == strongSelf) {
        return;
      }
      if (!didSucceed) {
        // The response never reached the peer, so running its next pipelined request - possibly
        // a mutating one - would change device state for a client that can no longer be answered.
        [FBLogger log:@"Failed to write a response; dropping the connection and its pending requests"];
        [strongSelf closeClient:client];
        return;
      }
      // Lifting the exemption and resuming parsing happen in one step on bufferProcessingQueue,
      // the queue the reaper also runs on: doing it out here exposes the connection to a sweep
      // queued ahead of the parse, which would judge a buffered request by the previous one's
      // timestamp.
      dispatch_async(strongSelf.bufferProcessingQueue, ^{
        __strong typeof(weakSelf) queuedSelf = weakSelf;
        if (nil == queuedSelf) {
          return;
        }
        @synchronized (queuedSelf.connectionBuffers) {
          [queuedSelf.connectionsAwaitingResponse removeObject:client];
          // Mid-request connections get their window from when parsing could resume, not from the
          // previous request. Absent entries stay absent, so idle keep-alives remain exempt.
          if (nil != [queuedSelf.incompleteRequestStarts objectForKey:client]) {
            [queuedSelf.incompleteRequestStarts setObject:[NSDate date] forKey:client];
          }
        }
        [queuedSelf processBufferForClient:client];
      });
    }];
  }
}

- (void)closeClient:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
    [self.pendingRequestHeaders removeObjectForKey:client];
    [self.connectionsAwaitingResponse removeObject:client];
    [self.incompleteRequestStarts removeObjectForKey:client];
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
