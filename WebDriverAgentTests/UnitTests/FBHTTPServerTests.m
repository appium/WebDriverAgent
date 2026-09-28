/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <arpa/inet.h>
#import <stdatomic.h>
#import <sys/socket.h>
#import <unistd.h>

#import "FBHTTPServer.h"

static atomic_int gFramingProbeHits;

// The response in `data` once all of it has arrived - its header block and Content-Length body -
// or nil while more is due.
static NSString *FBCompleteResponse(NSData *data)
{
  NSData *separator = (NSData * _Nonnull)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
  NSRange headerEnd = [data rangeOfData:separator options:(NSDataSearchOptions)0 range:NSMakeRange(0, data.length)];
  if (NSNotFound == headerEnd.location) {
    return nil;
  }
  NSString *headers = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, headerEnd.location)] encoding:NSUTF8StringEncoding];
  NSUInteger contentLength = 0;
  for (NSString *line in [headers componentsSeparatedByString:@"\r\n"]) {
    NSArray<NSString *> *field = [line componentsSeparatedByString:@":"];
    if (2 == field.count && NSOrderedSame == [field[0] caseInsensitiveCompare:@"Content-Length"]) {
      contentLength = (NSUInteger)[field[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].integerValue;
    }
  }
  if (data.length < NSMaxRange(headerEnd) + contentLength) {
    return nil;
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// Exercises FBHTTPServer's HTTP framing defenses with raw socket data that URL-loading APIs
// cannot produce: malformed Content-Length values and header blocks that never terminate.
@interface FBHTTPServerTests : XCTestCase
@property (nonatomic, strong) FBHTTPServer *server;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) dispatch_semaphore_t slowRouteStarted;
@end

@implementation FBHTTPServerTests

- (void)setUp
{
  [super setUp];
  atomic_store(&gFramingProbeHits, 0);
  self.server = [FBHTTPServer new];
  [self.server handleMethod:@"POST" withPath:@"/framing/probe" block:^(RouteRequest *request, RouteResponse *response) {
    atomic_fetch_add(&gFramingProbeHits, 1);
    [response respondWithString:@"probe-ok"];
  }];
  [self.server get:@"/framing/ping" withBlock:^(RouteRequest *request, RouteResponse *response) {
    [response respondWithString:@"pong"];
  }];
  dispatch_semaphore_t slowRouteStarted = dispatch_semaphore_create(0);
  self.slowRouteStarted = slowRouteStarted;
  [self.server get:@"/framing/slow" withBlock:^(RouteRequest *request, RouteResponse *response) {
    dispatch_semaphore_signal(slowRouteStarted);
    [NSThread sleepForTimeInterval:0.5];
    [response respondWithString:@"slow-ok"];
  }];
  self.server.port = 0;
  NSError *error;
  XCTAssertTrue([self.server start:&error], @"%@", error);
  self.port = [[self.server valueForKeyPath:@"socket.port"] unsignedShortValue];
}

- (void)tearDown
{
  [self.server stop:NO];
  self.server = nil;
  [super tearDown];
}

// A socket connected to the server that gives up reading after `timeout`, or -1.
- (int)connectedSocketWithTimeout:(NSTimeInterval)timeout
{
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  int noSigpipe = 1;
  setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, sizeof(noSigpipe));
  struct timeval tv = { .tv_sec = (long)timeout, .tv_usec = 0 };
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  struct sockaddr_in addr = { .sin_family = AF_INET, .sin_port = htons(self.port) };
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (0 != connect(fd, (struct sockaddr *)&addr, sizeof(addr))) {
    close(fd);
    return -1;
  }
  return fd;
}

// Descriptors in this process bound to the server's port: its listener plus one per server-side
// connection still open. Client sockets are bound to ephemeral ports, so they never count.
- (NSInteger)serverSocketCount
{
  NSInteger count = 0;
  int limit = getdtablesize();
  for (int fd = 0; fd < limit; fd++) {
    struct sockaddr_storage addr;
    socklen_t length = sizeof(addr);
    if (0 != getsockname(fd, (struct sockaddr *)&addr, &length)) {
      continue;
    }
    in_port_t port = 0;
    if (AF_INET == addr.ss_family) {
      port = ((struct sockaddr_in *)&addr)->sin_port;
    } else if (AF_INET6 == addr.ss_family) {
      port = ((struct sockaddr_in6 *)&addr)->sin6_port;
    }
    if (ntohs(port) == self.port) {
      count++;
    }
  }
  return count;
}

// The server learns about hang-ups asynchronously: polls until it holds `expected` sockets or
// 5 seconds pass, and returns the last count.
- (NSInteger)serverSocketCountSettlingAt:(NSInteger)expected
{
  NSInteger count = [self serverSocketCount];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
  while (count != expected && deadline.timeIntervalSinceNow > 0) {
    [NSThread sleepForTimeInterval:0.05];
    count = [self serverSocketCount];
  }
  return count;
}

// Sends `request` on a new connection, reads its complete response and then hangs up first, the
// way curl or iproxy end a keep-alive exchange. Returns nil unless the server answered and still
// held its side open when the client hung up.
- (NSString *)responseClosingFirstForRequest:(NSString *)request
{
  int fd = [self connectedSocketWithTimeout:5.0];
  if (fd < 0) {
    return nil;
  }
  NSData *payload = (NSData * _Nonnull)[request dataUsingEncoding:NSUTF8StringEncoding];
  send(fd, payload.bytes, payload.length, 0);
  NSMutableData *received = [NSMutableData data];
  NSString *response = nil;
  char chunk[4096];
  while (nil == response) {
    ssize_t n = recv(fd, chunk, sizeof(chunk), 0);
    if (n <= 0) {
      break;
    }
    [received appendBytes:chunk length:(NSUInteger)n];
    response = FBCompleteResponse(received);
  }
  char probe;
  BOOL isStillOpen = -1 == recv(fd, &probe, 1, MSG_PEEK | MSG_DONTWAIT) && EAGAIN == errno;
  close(fd);
  return isStillOpen ? response : nil;
}

// Sends `payload` as-is and reads until the server closes the connection or `timeout` elapses.
// Returns everything received (nil on connect failure); *didClose reports whether EOF was seen.
- (NSString *)responseForRawPayload:(NSData *)payload timeout:(NSTimeInterval)timeout didClose:(BOOL *)didClose
{
  *didClose = NO;
  int fd = [self connectedSocketWithTimeout:timeout];
  if (fd < 0) {
    return nil;
  }
  // send(2) may write only part of the payload, which would truncate the multi-KiB flood
  // payloads into something the server answers differently. Errors stay ignored on purpose:
  // those same tests expect the server to close the connection mid-send.
  const uint8_t *bytes = payload.bytes;
  size_t remaining = payload.length;
  while (remaining > 0) {
    ssize_t sent = send(fd, bytes, remaining, 0);
    if (sent <= 0) {
      break;
    }
    bytes += sent;
    remaining -= (size_t)sent;
  }
  NSMutableData *received = [NSMutableData data];
  char chunk[4096];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (deadline.timeIntervalSinceNow > 0) {
    ssize_t n = recv(fd, chunk, sizeof(chunk), 0);
    if (n == 0) {
      *didClose = YES;
      break;
    }
    if (n < 0) {
      // A read timeout. Only stop waiting once the response is a keep-alive success, where no
      // EOF is ever coming; every other response precedes a close, and giving up here would
      // report didClose = NO for a connection the server is about to drop.
      NSString *soFar = [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding] ?: @"";
      if ([soFar containsString:@"HTTP/1.1 200"]) {
        break;
      }
      continue;
    }
    [received appendBytes:chunk length:(NSUInteger)n];
    // The response has started arriving; poll in short slices from here so a keep-alive success
    // doesn't sit out the whole timeout waiting for an EOF that never comes.
    struct timeval drainTv = { .tv_sec = 0, .tv_usec = 200000 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &drainTv, sizeof(drainTv));
  }
  close(fd);
  return [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding] ?: @"";
}

- (void)testWellFormedRequestStillSucceeds
{
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[@"GET /framing/ping HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"200"], @"%@", response);
  XCTAssertTrue([response containsString:@"pong"], @"%@", response);
}

- (void)testConnectionsTheClientClosesReleaseTheirSockets
{
  // The server keeps a connection open after answering, so the client is the one that hangs up.
  // Each such connection must give its server-side socket back, or a long-running server
  // eventually fails every request with EMFILE.
  NSInteger baseline = [self serverSocketCount];
  for (int i = 0; i < 50; i++) {
    NSString *response = [self responseClosingFirstForRequest:@"GET /framing/ping HTTP/1.1\r\n\r\n"];
    XCTAssertTrue([response containsString:@"pong"], @"%@", response);
  }
  XCTAssertEqual([self serverSocketCountSettlingAt:baseline], baseline);
}

- (void)testHalfClosedClientGetsItsResponseAndIsThenClosed
{
  // A client may shut down its sending side right after the request and wait for the response.
  // Its end-of-stream must not cost it that response, and the server must close afterwards.
  NSInteger baseline = [self serverSocketCount];
  int fd = [self connectedSocketWithTimeout:5.0];
  XCTAssertGreaterThanOrEqual(fd, 0);
  NSData *payload = (NSData * _Nonnull)[@"GET /framing/slow HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertEqual(send(fd, payload.bytes, payload.length, 0), (ssize_t)payload.length);
  XCTAssertEqual(dispatch_semaphore_wait(self.slowRouteStarted, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC))), 0L);
  XCTAssertEqual(shutdown(fd, SHUT_WR), 0);
  NSMutableData *received = [NSMutableData data];
  char chunk[4096];
  ssize_t n;
  while ((n = recv(fd, chunk, sizeof(chunk), 0)) > 0) {
    [received appendBytes:chunk length:(NSUInteger)n];
  }
  close(fd);
  NSString *response = [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding];
  XCTAssertTrue([response containsString:@"slow-ok"], @"%@", response);
  XCTAssertEqual(n, (ssize_t)0, @"the server must close the connection once it has answered");
  XCTAssertEqual([self serverSocketCountSettlingAt:baseline], baseline);
}

- (void)testNonNumericContentLengthIsRejected
{
  // Under -integerValue's lenient parsing "bogus" became 0: the probe route would run with an
  // empty body and the smuggled GET below would be answered as a second pipelined request.
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nContent-Length: bogus\r\n\r\nGET /framing/ping HTTP/1.1\r\n\r\n";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertFalse([response containsString:@"pong"], @"the smuggled request must not be answered: %@", response);
  XCTAssertTrue(didClose, @"the connection must be closed after unparseable framing");
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0, @"the route must not be dispatched with unknown body extent");
}

- (void)testWhitespaceBeforeHeaderColonIsRejected
{
  // RFC 7230 (3.2.4): whitespace between a field name and its colon MUST be rejected with a 400.
  // Tolerating it stores "content-length " as a distinct key, dispatches the request with a
  // zero-length body, and re-parses the declared body as a smuggled pipelined request.
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nContent-Length : 5\r\n\r\nhello";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertTrue(didClose);
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0);
}

- (void)testHeaderLineWithoutColonIsRejected
{
  // Silently skipping the malformed line made this dispatch with an empty body while "hello"
  // stayed in the buffer to be parsed as the next request.
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nContent-Length 5\r\n\r\nhello";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertTrue(didClose);
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0);
}

- (void)testDuplicateContentLengthIsRejected
{
  // RFC 7230 (3.3.3): repeated framing fields are unrecoverable. Last-wins assignment would let
  // the second value drive parsing while an intermediary used the first - a smuggling primitive.
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nContent-Length: 5\r\nContent-Length: 0\r\n\r\nhello";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertTrue(didClose);
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0);
}

- (void)testEmptyTransferEncodingIsRejected
{
  // "chunked" followed by an empty value: with last-wins assignment plus a non-empty presence
  // check, the empty value used to make the header look absent, so the chunked body was parsed
  // as a zero-length body and its bytes re-read as smuggled requests.
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: \r\n\r\n0\r\n\r\n";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"] || [response containsString:@"501"], @"%@", response);
  XCTAssertTrue(didClose);
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0);
}

- (void)testPipelinedRequestsAreServedInOrder
{
  // Two requests in one payload: both must be answered on the same connection. Guards the
  // response backpressure logic - the next pipelined request is only processed once the
  // previous response's send completed, which must not stall or reorder the pipeline.
  NSString *payload = @"GET /framing/ping HTTP/1.1\r\n\r\nGET /framing/ping HTTP/1.1\r\n\r\n";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  NSUInteger pongCount = [response componentsSeparatedByString:@"pong"].count - 1;
  XCTAssertEqual(pongCount, 2, @"both pipelined requests must be answered: %@", response);
}

- (void)testPartiallyNumericContentLengthIsRejected
{
  NSString *payload = @"POST /framing/probe HTTP/1.1\r\nContent-Length: 5abc\r\n\r\nhello";
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertTrue(didClose);
  XCTAssertEqual(atomic_load(&gFramingProbeHits), 0);
}

- (void)testOversizedHeaderBlockIsRejected
{
  // A header block that never terminates: 96 KiB of header lines with no \r\n\r\n. The server
  // must stop buffering and close the connection instead of growing the buffer indefinitely.
  NSMutableString *payload = [NSMutableString stringWithString:@"GET /framing/ping HTTP/1.1\r\n"];
  NSString *filler = [@"X-Filler: " stringByAppendingString:[@"" stringByPaddingToLength:1013 withString:@"a" startingAtIndex:0]];
  while (payload.length < 96 * 1024) {
    [payload appendString:filler];
    [payload appendString:@"\r\n"];
  }
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:10.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertTrue(didClose, @"the connection must be closed rather than left buffering");
}

- (void)testOversizedCompletedHeaderBlockIsRejected
{
  // Same flood, but properly terminated with \r\n\r\n. Depending on how the bytes coalesce, the
  // terminator can arrive in the same receive callback as the bulk of the block, in which case
  // the incomplete-header cap never fires - the completed block must be rejected too instead of
  // being copied and parsed.
  NSMutableString *payload = [NSMutableString stringWithString:@"GET /framing/ping HTTP/1.1\r\n"];
  NSString *filler = [@"X-Filler: " stringByAppendingString:[@"" stringByPaddingToLength:1013 withString:@"a" startingAtIndex:0]];
  while (payload.length < 96 * 1024) {
    [payload appendString:filler];
    [payload appendString:@"\r\n"];
  }
  [payload appendString:@"\r\n"];
  BOOL didClose;
  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[payload dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:10.0
                                           didClose:&didClose];
  XCTAssertTrue([response containsString:@"400"], @"%@", response);
  XCTAssertFalse([response containsString:@"pong"], @"the oversized request must not be served: %@", response);
  XCTAssertTrue(didClose, @"the connection must be closed rather than left buffering");
}

@end
