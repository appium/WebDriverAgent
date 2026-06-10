/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBroadcastSampleHandler.h"

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#import "FBBroadcastProtocol.h"
#import "FBExtBroadcastClient.h"
#import "FBExtLogging.h"
#import "FBExtSessionPipeline.h"

static NSString *const FBBroadcastSampleHandlerErrorDomain = @"com.facebook.WebDriverAgent.FBBroadcastSampleHandler";

@interface FBBroadcastSampleHandler () <FBExtBroadcastClientDelegate>

@property (nonatomic, nullable) FBExtBroadcastClient *client;

@end

@implementation FBBroadcastSampleHandler

- (void)broadcastStartedWithSetupInfo:(nullable NSDictionary<NSString *, NSObject *> *)setupInfo
{
  // setupInfo is nil for broadcasts started from the system picker; nothing to read from it.
  FBExtLogInfo("Broadcast started");
  self.client = [[FBExtBroadcastClient alloc] init];
  self.client.delegate = self;
  [self.client start];
}

- (void)broadcastPaused
{
  FBExtLogInfo("Broadcast paused");
  self.client.paused = YES;
  [self sendStatusEvent:@"paused" reason:nil];
}

- (void)broadcastResumed
{
  FBExtLogInfo("Broadcast resumed");
  self.client.paused = NO;
  [self sendStatusEvent:@"resumed" reason:nil];
}

- (void)broadcastFinished
{
  FBExtLogInfo("Broadcast finished");
  [self sendStatusEvent:@"finishing" reason:@"broadcastFinished"];
  [self.client shutdown];
  self.client = nil;
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   withType:(RPSampleBufferType)sampleBufferType
{
  if (sampleBufferType != RPSampleBufferTypeVideo) {
    // Audio capture is a planned follow-up.
    return;
  }
  FBExtBroadcastClient *client = self.client;
  if (nil == client) {
    return;
  }

  client.framesReceived += 1;

  CFTypeRef orientationAttachment = CMGetAttachment(sampleBuffer,
                                                    (__bridge CFStringRef)RPVideoSampleOrientationKey,
                                                    NULL);
  if (NULL != orientationAttachment) {
    client.currentOrientation = (uint8_t)[(__bridge NSNumber *)orientationAttachment unsignedIntValue];
  }

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (NULL != pixelBuffer && client.screenWidth == 0) {
    client.screenWidth = CVPixelBufferGetWidth(pixelBuffer);
    client.screenHeight = CVPixelBufferGetHeight(pixelBuffer);
  }

  NSDictionary<NSNumber *, FBExtSessionPipeline *> *pipelines = client.activePipelines;
  for (FBExtSessionPipeline *pipeline in pipelines.allValues) {
    [pipeline submitSampleBuffer:sampleBuffer orientation:client.currentOrientation];
  }
}

- (void)sendStatusEvent:(NSString *)event reason:(nullable NSString *)reason
{
  NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithObject:event
                                                                    forKey:FBBroadcastKeyEvent];
  if (nil != reason) {
    payload[FBBroadcastKeyReason] = reason;
  }
  NSData *message = FBBroadcastEncodeJSONMessage(FBBroadcastMessageTypeStatus, 0, payload);
  if (nil != message) {
    [self.client sendProtocolMessage:message isDroppable:NO];
  }
}

- (void)finishBroadcast
{
  // The public API only offers finishBroadcastWithError:, which makes the system show an error
  // alert. The private graceful variant avoids that; fall back to the public one when absent.
  SEL gracefulSelector = NSSelectorFromString(@"finishBroadcastGracefully:");
  if ([self respondsToSelector:gracefulSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:gracefulSelector withObject:nil];
#pragma clang diagnostic pop
    return;
  }
  NSError *error = [NSError errorWithDomain:FBBroadcastSampleHandlerErrorDomain
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"WebDriverAgent stopped the broadcast"}];
  [self finishBroadcastWithError:error];
}

#pragma mark - <FBExtBroadcastClientDelegate>

- (void)broadcastClientDidRequestStop:(FBExtBroadcastClient *)client
{
  [self sendStatusEvent:@"finishing" reason:@"stopRequested"];
  [self finishBroadcast];
}

- (void)broadcastClient:(FBExtBroadcastClient *)client didFailPermanently:(NSError *)error
{
  FBExtLogError("Finishing the broadcast: %{public}@", error.description);
  [self finishBroadcastWithError:error];
}

@end
