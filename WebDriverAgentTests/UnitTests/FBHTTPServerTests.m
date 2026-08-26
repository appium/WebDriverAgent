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

// Exercises FBHTTPServer's HTTP framing defenses with raw socket data that URL-loading APIs
// cannot produce: malformed Content-Length values and header blocks that never terminate.
@interface FBHTTPServerTests : XCTestCase
@property (nonatomic, strong) FBHTTPServer *server;
@property (nonatomic, assign) uint16_t port;
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

// Sends `payload` as-is and reads until the server closes the connection or `timeout` elapses.
// Returns everything received (nil on connect failure); *didClose reports whether EOF was seen.
- (NSString *)responseForRawPayload:(NSData *)payload timeout:(NSTimeInterval)timeout didClose:(BOOL *)didClose
{
  *didClose = NO;
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return nil;
  }
  int noSigpipe = 1;
  setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigpipe, sizeof(noSigpipe));
  struct timeval tv = { .tv_sec = (long)timeout, .tv_usec = 0 };
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  struct sockaddr_in addr = { .sin_family = AF_INET, .sin_port = htons(self.port) };
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (0 != connect(fd, (struct sockaddr *)&addr, sizeof(addr))) {
    close(fd);
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
