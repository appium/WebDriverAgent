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

#import "FBHTTPServer.h"

static atomic_int gSessionProbeHits;

@interface FBHTTPServerSessionTests : XCTestCase
@property (nonatomic, strong) FBHTTPServer *server;
@property (nonatomic, assign) uint16_t port;
@end

@implementation FBHTTPServerSessionTests

- (void)setUp
{
  [super setUp];
  atomic_store(&gSessionProbeHits, 0);
  self.server = [FBHTTPServer new];
  [self.server get:@"/session/:sessionID/probe" withBlock:^(RouteRequest *request, RouteResponse *response) {
    atomic_fetch_add(&gSessionProbeHits, 1);
    [response respondWithString:@"session-probe-ok"];
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

- (NSString *)responseForRawPayload:(NSData *)payload timeout:(NSTimeInterval)timeout
{
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
  send(fd, payload.bytes, payload.length, 0);
  NSMutableData *received = [NSMutableData data];
  char chunk[4096];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (deadline.timeIntervalSinceNow > 0) {
    ssize_t n = recv(fd, chunk, sizeof(chunk), 0);
    if (n > 0) {
      [received appendBytes:chunk length:(NSUInteger)n];
      // The server keeps the connection open after a success, so don't wait the full timeout
      // for an EOF that never comes.
      struct timeval drainTv = { .tv_sec = 0, .tv_usec = 200000 };
      setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &drainTv, sizeof(drainTv));
    } else {
      break;
    }
  }
  close(fd);
  return [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding] ?: @"";
}

- (void)testRequestForAlreadyAbandonedSessionIsRejectedImmediately
{
  // A request parsed *after* DELETE /session tore the session down never receives an abandonment
  // notification of its own, so before this was tracked it queued on the route queue -
  // potentially forever, if that queue is wedged behind the very request that made the client
  // delete the session in the first place.
  RouteResponse *abandonedResponse = [RouteResponse new];
  [abandonedResponse respondWithString:@"session-was-deleted"];
  [self.server abandonPendingRequestsForSessionID:@"dead-session" withResponse:abandonedResponse];

  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[@"GET /session/dead-session/probe HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0];
  XCTAssertTrue([response containsString:@"session-was-deleted"], @"%@", response);
  XCTAssertEqual(atomic_load(&gSessionProbeHits), 0, @"the route must not run for a deleted session");
}

- (void)testAbandonedSessionIsRememberedAfterManyLaterAbandonments
{
  // Abandoned ids are kept for the server's lifetime; evicting them would let a stale request
  // queue on a possibly wedged route queue again, which is the hang this rejection prevents.
  RouteResponse *abandonedResponse = [RouteResponse new];
  [abandonedResponse respondWithString:@"session-was-deleted"];
  [self.server abandonPendingRequestsForSessionID:@"dead-session" withResponse:abandonedResponse];
  for (NSUInteger index = 0; index < 64; ++index) {
    RouteResponse *otherResponse = [RouteResponse new];
    [otherResponse respondWithString:@"other-session-was-deleted"];
    [self.server abandonPendingRequestsForSessionID:[NSString stringWithFormat:@"other-session-%lu", (unsigned long)index]
                                       withResponse:otherResponse];
  }

  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[@"GET /session/dead-session/probe HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0];
  XCTAssertTrue([response containsString:@"session-was-deleted"], @"%@", response);
  XCTAssertEqual(atomic_load(&gSessionProbeHits), 0, @"the route must not run for a deleted session");
}

- (void)testRequestForLiveSessionIsStillServed
{
  // The rejection above must be scoped to the abandoned identifier only.
  RouteResponse *abandonedResponse = [RouteResponse new];
  [abandonedResponse respondWithString:@"session-was-deleted"];
  [self.server abandonPendingRequestsForSessionID:@"dead-session" withResponse:abandonedResponse];

  NSString *response = [self responseForRawPayload:(NSData * _Nonnull)[@"GET /session/live-session/probe HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                            timeout:5.0];
  XCTAssertTrue([response containsString:@"session-probe-ok"], @"%@", response);
  XCTAssertEqual(atomic_load(&gSessionProbeHits), 1);
}

@end
