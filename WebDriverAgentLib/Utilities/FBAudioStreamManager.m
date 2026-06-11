/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAudioStreamManager.h"

#import "FBBroadcastManager.h"
#import "FBConfiguration.h"
#import "FBLogger.h"

static const NSUInteger MAX_SESSIONS = 8;
// How many successive ports to try when auto-assigning, so a default port already bound by
// another process (e.g. a stale WDA) does not block startup.
static const NSUInteger PORT_SCAN_RANGE = 64;

@interface FBAudioStreamManager ()

@property (nonatomic) NSMutableDictionary<NSNumber *, FBAudioStreamSession *> *sessions;
@property (nonatomic) NSUInteger nextSessionIdentifier;
// Starts that reserved a slot under the lock but have not yet inserted their session (the
// socket bind happens outside the lock). Counted toward the cap so concurrent starts cannot
// collectively exceed MAX_SESSIONS.
@property (nonatomic) NSUInteger pendingStarts;

@end


@implementation FBAudioStreamManager

+ (instancetype)sharedInstance
{
  static FBAudioStreamManager *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _sessions = [NSMutableDictionary dictionary];
    _nextSessionIdentifier = 1;
  }
  return self;
}

- (nullable FBAudioStreamSession *)startSessionWithConfiguration:(FBAudioCaptureConfiguration *)configuration
                                                           error:(NSError **)error
{
  NSUInteger identifier;
  BOOL autoAssignPort = (0 == configuration.port);
  @synchronized (self.sessions) {
    if (self.sessions.count + self.pendingStarts >= MAX_SESSIONS) {
      if (error) {
        *error = [NSError errorWithDomain:@"com.facebook.WebDriverAgent.FBAudioStreamManager"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The maximum number of concurrent audio capture sessions (%@) has been reached", @(MAX_SESSIONS)]}];
      }
      return nil;
    }
    if (autoAssignPort) {
      configuration.port = [self nextAutoPortLocked];
    }
    // Reserve the identifier and a slot under the lock so concurrent starts cannot collide.
    identifier = self.nextSessionIdentifier;
    self.nextSessionIdentifier += 1;
    self.pendingStarts += 1;
  }

  FBAudioStreamSession *session = [self startBoundSessionWithIdentifier:identifier
                                                          configuration:configuration
                                                         autoAssignPort:autoAssignPort
                                                                  error:error];
  @synchronized (self.sessions) {
    self.pendingStarts -= 1;
    if (nil != session) {
      self.sessions[@(identifier)] = session;
    }
  }
  if (nil == session) {
    return nil;
  }

  // Attach the session to the broadcast extension (if connected); otherwise the SESSION_ADD is
  // sent when the extension connects.
  [FBBroadcastManager.sharedInstance notifyAudioSessionAdded:session];
  [FBLogger logFmt:@"Started audio capture session %@ (opus %@ch %@bps) on port %@",
   @(identifier), @(configuration.channels), @(configuration.bitrate), @(configuration.port)];
  return session;
}

- (uint16_t)nextAutoPortLocked
{
  uint16_t base = (uint16_t)FBConfiguration.audioCaptureServerPort;
  NSMutableSet<NSNumber *> *used = [NSMutableSet set];
  for (FBAudioStreamSession *session in self.sessions.allValues) {
    [used addObject:@(session.configuration.port)];
  }
  uint16_t port = base;
  while ([used containsObject:@(port)] && port < UINT16_MAX) {
    port += 1;
  }
  return port;
}

- (nullable FBAudioStreamSession *)startBoundSessionWithIdentifier:(NSUInteger)identifier
                                                     configuration:(FBAudioCaptureConfiguration *)configuration
                                                    autoAssignPort:(BOOL)autoAssignPort
                                                             error:(NSError **)error
{
  // For an explicit port we try exactly once and surface any bind failure. For auto-assignment
  // we scan forward so a default port already held by another process does not block startup.
  NSUInteger maxAttempts = autoAssignPort ? PORT_SCAN_RANGE : 1;
  NSError *lastError = nil;
  for (NSUInteger attempt = 0; attempt < maxAttempts; attempt++) {
    FBAudioStreamSession *session = [[FBAudioStreamSession alloc] initWithIdentifier:identifier
                                                                       configuration:configuration];
    if ([session startWithError:&lastError]) {
      return session;
    }
    if (!autoAssignPort || configuration.port >= UINT16_MAX) {
      break;
    }
    configuration.port += 1;
  }
  if (error) {
    *error = lastError;
  }
  return nil;
}

- (BOOL)stopSessionWithIdentifier:(NSUInteger)identifier
{
  FBAudioStreamSession *session;
  @synchronized (self.sessions) {
    session = self.sessions[@(identifier)];
    if (nil == session) {
      return NO;
    }
    [self.sessions removeObjectForKey:@(identifier)];
  }
  [session stop];
  [FBBroadcastManager.sharedInstance notifyAudioSessionRemoved:identifier];
  [FBLogger logFmt:@"Stopped audio capture session %@", @(identifier)];
  return YES;
}

- (nullable FBAudioStreamSession *)sessionWithIdentifier:(NSUInteger)identifier
{
  @synchronized (self.sessions) {
    return self.sessions[@(identifier)];
  }
}

- (NSArray<FBAudioStreamSession *> *)activeSessions
{
  @synchronized (self.sessions) {
    return self.sessions.allValues;
  }
}

- (NSArray<NSDictionary *> *)activeSessionsInfo
{
  NSArray<FBAudioStreamSession *> *snapshot;
  @synchronized (self.sessions) {
    snapshot = self.sessions.allValues;
  }
  NSArray<FBAudioStreamSession *> *sorted = [snapshot sortedArrayUsingComparator:^NSComparisonResult(FBAudioStreamSession *a, FBAudioStreamSession *b) {
    return [@(a.identifier) compare:@(b.identifier)];
  }];
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  for (FBAudioStreamSession *session in sorted) {
    [result addObject:session.toDictionary];
  }
  return result.copy;
}

- (void)stopAllSessions
{
  NSArray<FBAudioStreamSession *> *snapshot;
  @synchronized (self.sessions) {
    snapshot = self.sessions.allValues;
    [self.sessions removeAllObjects];
  }
  for (FBAudioStreamSession *session in snapshot) {
    [session stop];
    [FBBroadcastManager.sharedInstance notifyAudioSessionRemoved:session.identifier];
  }
}

@end
