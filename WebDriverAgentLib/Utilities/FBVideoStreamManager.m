/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBVideoStreamManager.h"

#import <mach/mach_time.h>
#import <ImageIO/ImageIO.h>
@import UniformTypeIdentifiers;

#import "FBBroadcastManager.h"
#import "FBConfiguration.h"
#import "FBImageUtils.h"
#import "FBLogger.h"
#import "FBScreenshot.h"
#import "XCUIScreen.h"

static const NSUInteger MAX_FPS = 60;
static const NSUInteger DEFAULT_LOOP_FPS = 30;
static const NSUInteger MAX_SESSIONS = 8;
// How many successive ports to try when auto-assigning, so a default port already bound by
// another process (e.g. a stale WDA) does not block startup.
static const NSUInteger PORT_SCAN_RANGE = 64;
static const NSTimeInterval FRAME_TIMEOUT = 1.0;
static const NSTimeInterval FAILURE_BACKOFF_MIN = 1.0;
static const NSTimeInterval FAILURE_BACKOFF_MAX = 10.0;
static const CGFloat CAPTURE_COMPRESSION_QUALITY = 0.8;
static const char *QUEUE_NAME = "Screen Capture Encoder Queue";

@interface FBVideoStreamManager ()

@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (nonatomic) NSMutableDictionary<NSNumber *, FBVideoStreamSession *> *sessions;
@property (nonatomic) NSUInteger nextSessionIdentifier;
// Starts that reserved a slot under the lock but have not yet inserted their session (the
// bind/encoder start happens outside the lock). Counted toward the cap so concurrent starts
// cannot collectively exceed MAX_SESSIONS.
@property (nonatomic) NSUInteger pendingStarts;
@property (nonatomic) long long mainScreenID;
@property (nonatomic) NSUInteger consecutiveScreenshotFailures;
@property (atomic) BOOL isStreaming;
// Identifies the current capture-loop run. Callbacks scheduled by a previous run carry a stale
// generation and refuse to proceed, so a stop/start cycle cannot leave duplicate loops running.
@property (atomic) NSUInteger loopGeneration;

@end


@implementation FBVideoStreamManager

+ (instancetype)sharedInstance
{
  static FBVideoStreamManager *instance;
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
    _isStreaming = NO;
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
  }
  return self;
}

- (nullable FBVideoStreamSession *)startSessionWithConfiguration:(FBScreenCaptureConfiguration *)configuration
                                                          error:(NSError **)error
{
  NSUInteger identifier;
  BOOL shouldStartLoop = NO;
  BOOL autoAssignPort = (0 == configuration.port);
  @synchronized (self.sessions) {
    // Count in-flight starts toward the cap: their sessions are not inserted until after the
    // (slow) bind/encoder start, so without this two concurrent starts could both pass the check
    // and exceed MAX_SESSIONS.
    if (self.sessions.count + self.pendingStarts >= MAX_SESSIONS) {
      if (error) {
        *error = [NSError errorWithDomain:@"com.facebook.WebDriverAgent.FBVideoStreamManager"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The maximum number of concurrent screen capture sessions (%@) has been reached", @(MAX_SESSIONS)]}];
      }
      return nil;
    }
    if (autoAssignPort) {
      configuration.port = [self nextAutoPortLocked];
    }
    // Reserve the identifier and a slot under the lock. Otherwise two concurrent starts read the
    // same id (it was previously incremented only after the slow socket/encoder bind, outside the
    // lock) and the later insert overwrites the earlier session, orphaning its still-running
    // server with no id to stop it by.
    identifier = self.nextSessionIdentifier;
    self.nextSessionIdentifier += 1;
    self.pendingStarts += 1;
  }

  FBVideoStreamSession *session = [self startBoundSessionWithIdentifier:identifier
                                                         configuration:configuration
                                                        autoAssignPort:autoAssignPort
                                                                 error:error];
  if (nil == session) {
    @synchronized (self.sessions) {
      self.pendingStarts -= 1;
    }
    return nil;
  }

  NSUInteger generation = 0;
  @synchronized (self.sessions) {
    self.pendingStarts -= 1;
    self.sessions[@(identifier)] = session;
    self.mainScreenID = [XCUIScreen.mainScreen displayID];
    if (!self.isStreaming) {
      self.isStreaming = YES;
      self.loopGeneration += 1;
      shouldStartLoop = YES;
    }
    generation = self.loopGeneration;
  }

  if (shouldStartLoop) {
    self.consecutiveScreenshotFailures = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.backgroundQueue, ^{
      [weakSelf captureFrameWithGeneration:generation];
    });
  }
  // Attach the session to the broadcast extension (if connected): the session keeps serving
  // locally encoded screenshot frames until the extension's first key frame arrives.
  session.onBroadcastKeyFrameNeeded = ^(NSUInteger sessionIdentifier) {
    [FBBroadcastManager.sharedInstance requestKeyFrameForSession:sessionIdentifier];
  };
  [FBBroadcastManager.sharedInstance notifySessionAdded:session];
  [FBLogger logFmt:@"Started screen capture session %@ (%@ %@x%@) on port %@",
   @(identifier), session.toDictionary[@"codec"], @(configuration.width), @(configuration.height), @(configuration.port)];
  return session;
}

- (uint16_t)nextAutoPortLocked
{
  uint16_t base = (uint16_t)FBConfiguration.screenCaptureServerPort;
  NSMutableSet<NSNumber *> *used = [NSMutableSet set];
  for (FBVideoStreamSession *session in self.sessions.allValues) {
    [used addObject:@(session.configuration.port)];
  }
  uint16_t port = base;
  while ([used containsObject:@(port)] && port < UINT16_MAX) {
    port += 1;
  }
  return port;
}

- (nullable FBVideoStreamSession *)startBoundSessionWithIdentifier:(NSUInteger)identifier
                                                    configuration:(FBScreenCaptureConfiguration *)configuration
                                                   autoAssignPort:(BOOL)autoAssignPort
                                                            error:(NSError **)error
{
  // For an explicit port we try exactly once and surface any bind failure. For auto-assignment
  // we scan forward so a default port already held by another process does not block startup.
  NSUInteger maxAttempts = autoAssignPort ? PORT_SCAN_RANGE : 1;
  NSError *lastError = nil;
  for (NSUInteger attempt = 0; attempt < maxAttempts; attempt++) {
    FBVideoStreamSession *session = [[FBVideoStreamSession alloc] initWithIdentifier:identifier
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
  FBVideoStreamSession *session;
  @synchronized (self.sessions) {
    session = self.sessions[@(identifier)];
    if (nil == session) {
      return NO;
    }
    [self.sessions removeObjectForKey:@(identifier)];
    if (0 == self.sessions.count) {
      self.isStreaming = NO;
    }
  }
  [session stop];
  [FBBroadcastManager.sharedInstance notifySessionRemoved:identifier];
  [FBLogger logFmt:@"Stopped screen capture session %@", @(identifier)];
  return YES;
}

- (BOOL)requestKeyFrameForSessionWithIdentifier:(NSUInteger)identifier
{
  FBVideoStreamSession *session = [self sessionWithIdentifier:identifier];
  if (nil == session) {
    return NO;
  }
  [session requestKeyFrame];
  return YES;
}

- (nullable FBVideoStreamSession *)sessionWithIdentifier:(NSUInteger)identifier
{
  @synchronized (self.sessions) {
    return self.sessions[@(identifier)];
  }
}

- (NSArray<NSDictionary *> *)activeSessionsInfo
{
  NSArray<FBVideoStreamSession *> *snapshot;
  @synchronized (self.sessions) {
    snapshot = self.sessions.allValues;
  }
  NSArray<FBVideoStreamSession *> *sorted = [snapshot sortedArrayUsingComparator:^NSComparisonResult(FBVideoStreamSession *a, FBVideoStreamSession *b) {
    return [@(a.identifier) compare:@(b.identifier)];
  }];
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  for (FBVideoStreamSession *session in sorted) {
    [result addObject:session.toDictionary];
  }
  return result.copy;
}

- (void)stopAllSessions
{
  NSArray<FBVideoStreamSession *> *snapshot;
  @synchronized (self.sessions) {
    snapshot = self.sessions.allValues;
    [self.sessions removeAllObjects];
    self.isStreaming = NO;
  }
  for (FBVideoStreamSession *session in snapshot) {
    [session stop];
    [FBBroadcastManager.sharedInstance notifySessionRemoved:session.identifier];
  }
}

- (NSArray<FBVideoStreamSession *> *)activeSessions
{
  @synchronized (self.sessions) {
    return self.sessions.allValues;
  }
}

#pragma mark - Shared capture loop

- (void)scheduleNextFrameWithInterval:(uint64_t)timerInterval
                          timeStarted:(uint64_t)timeStarted
                           generation:(NSUInteger)generation
{
  if (!self.isStreaming || generation != self.loopGeneration) {
    return;
  }
  uint64_t timeElapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted;
  int64_t nextTickDelta = (int64_t)timerInterval - (int64_t)timeElapsed;
  __weak typeof(self) weakSelf = self;
  if (nextTickDelta > 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nextTickDelta), self.backgroundQueue, ^{
      [weakSelf captureFrameWithGeneration:generation];
    });
  } else {
    dispatch_async(self.backgroundQueue, ^{
      [weakSelf captureFrameWithGeneration:generation];
    });
  }
}

- (void)captureFrameWithGeneration:(NSUInteger)generation
{
  // Ignore callbacks left over from a previous capture-loop run.
  if (!self.isStreaming || generation != self.loopGeneration) {
    return;
  }

  NSArray<FBVideoStreamSession *> *snapshot;
  @synchronized (self.sessions) {
    snapshot = self.sessions.allValues;
  }

  // The loop ticks at the fastest session's framerate; each session down-samples to its own fps.
  NSUInteger loopFps = 0;
  BOOL anyClients = NO;
  for (FBVideoStreamSession *session in snapshot) {
    loopFps = MAX(loopFps, session.configuration.fps);
    // Sessions fed by the broadcast extension do not need (expensive) XCTest screenshots; the
    // loop keeps ticking cheaply so it picks the screenshot capture back up if they detach.
    if ([session requiresLocalFrames]) {
      anyClients = YES;
    }
  }
  if (0 == loopFps || loopFps > MAX_FPS) {
    loopFps = MIN(MAX_FPS, MAX(loopFps, DEFAULT_LOOP_FPS));
  }
  uint64_t timerInterval = (uint64_t)(1.0 / (double)loopFps * NSEC_PER_SEC);
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

  if (!anyClients) {
    [self scheduleNextFrameWithInterval:timerInterval timeStarted:timeStarted generation:generation];
    return;
  }

  NSError *error;
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:self.mainScreenID
                                                           compressionQuality:CAPTURE_COMPRESSION_QUALITY
                                                                          uti:UTTypeJPEG
                                                                      timeout:FRAME_TIMEOUT
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    self.consecutiveScreenshotFailures++;
    NSTimeInterval backoffSeconds = MIN(FAILURE_BACKOFF_MAX,
                                        FAILURE_BACKOFF_MIN * (1 << MIN(self.consecutiveScreenshotFailures, 4)));
    [self scheduleNextFrameWithInterval:(uint64_t)(backoffSeconds * NSEC_PER_SEC) timeStarted:timeStarted generation:generation];
    return;
  }
  self.consecutiveScreenshotFailures = 0;

  // Decode the screenshot once (applying its EXIF orientation so landscape frames are upright)
  // and fan the shared image out to every session.
  CGImageRef image = FBCreateOrientedCGImageFromData(screenshotData);
  if (NULL != image) {
    uint64_t nowMs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / NSEC_PER_MSEC;
    for (FBVideoStreamSession *session in snapshot) {
      [session maybeEncodeCGImage:image atTimeMs:nowMs];
    }
    CGImageRelease(image);
  } else {
    [FBLogger log:@"Cannot decode the captured screenshot"];
  }

  [self scheduleNextFrameWithInterval:timerInterval timeStarted:timeStarted generation:generation];
}

@end
