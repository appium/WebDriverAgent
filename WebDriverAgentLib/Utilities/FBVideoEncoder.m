/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBVideoEncoder.h"

#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

NSErrorDomain const FBVideoEncoderErrorDomain = @"com.facebook.WebDriverAgent.FBVideoEncoder";

static const uint8_t FBAnnexBStartCode[4] = {0x00, 0x00, 0x00, 0x01};

@interface FBVideoEncoder ()
@property (nonatomic) VTCompressionSessionRef session;
@property (nonatomic) size_t nalUnitHeaderLength;
@property (atomic) BOOL forceNextKeyFrame;
@property (atomic, copy, readwrite, nullable) NSData *parameterSetAnnexB;

- (void)handleEncodedSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

static void FBCompressionOutputCallback(void *outputCallbackRefCon,
                                        void *sourceFrameRefCon,
                                        OSStatus status,
                                        VTEncodeInfoFlags infoFlags,
                                        CMSampleBufferRef sampleBuffer)
{
  if (status != noErr || NULL == sampleBuffer) {
    return;
  }
  if (!CMSampleBufferDataIsReady(sampleBuffer)) {
    return;
  }
  FBVideoEncoder *encoder = (__bridge FBVideoEncoder *)outputCallbackRefCon;
  [encoder handleEncodedSampleBuffer:sampleBuffer];
}

@implementation FBVideoEncoder

- (nullable instancetype)initWithCodec:(FBVideoCodec)codec
                                 width:(NSUInteger)width
                                height:(NSUInteger)height
                               bitrate:(NSUInteger)bitrate
                                   fps:(NSUInteger)fps
                                 error:(NSError **)error
{
  if ((self = [super init])) {
    _codec = codec;
    _width = width;
    _height = height;
    _bitrate = bitrate;
    _fps = MAX((NSUInteger)1, fps);
    _nalUnitHeaderLength = 4;
    _forceNextKeyFrame = NO;

    CMVideoCodecType codecType = (codec == FBVideoCodecH265) ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264;
    OSStatus createStatus = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                       (int32_t)width,
                                                       (int32_t)height,
                                                       codecType,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       FBCompressionOutputCallback,
                                                       (__bridge void *)self,
                                                       &_session);
    if (createStatus != noErr || NULL == _session) {
      if (error) {
        *error = [NSError errorWithDomain:FBVideoEncoderErrorDomain
                                     code:createStatus
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create a %@ compression session (status %d)", codec == FBVideoCodecH265 ? @"HEVC" : @"H.264", (int)createStatus]}];
      }
      return nil;
    }

    [self configureSession];
    VTCompressionSessionPrepareToEncodeFrames(_session);
  }
  return self;
}

- (void)configureSession
{
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);

  CFStringRef profileLevel = (self.codec == FBVideoCodecH265)
    ? kVTProfileLevel_HEVC_Main_AutoLevel
    : kVTProfileLevel_H264_High_AutoLevel;
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_ProfileLevel, profileLevel);

  CFNumberRef bitrateRef = (__bridge CFNumberRef)@(self.bitrate);
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_AverageBitRate, bitrateRef);

  CFNumberRef fpsRef = (__bridge CFNumberRef)@(self.fps);
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);

  // Emit a key frame at least every couple of seconds so that late joiners can sync.
  CFNumberRef maxInterval = (__bridge CFNumberRef)@(self.fps * 2);
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_MaxKeyFrameInterval, maxInterval);
  CFNumberRef maxIntervalDuration = (__bridge CFNumberRef)@(2);
  VTSessionSetProperty(self.session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, maxIntervalDuration);
}

- (BOOL)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer
        presentationTimeMs:(uint64_t)presentationTimeMs
                     error:(NSError **)error
{
  if (NULL == self.session) {
    if (error) {
      *error = [NSError errorWithDomain:FBVideoEncoderErrorDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey: @"The compression session is not available"}];
    }
    return NO;
  }

  CMTime presentationTime = CMTimeMake((int64_t)presentationTimeMs, 1000);
  NSDictionary *frameProperties = nil;
  if (self.forceNextKeyFrame) {
    self.forceNextKeyFrame = NO;
    frameProperties = @{(id)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
  }

  VTEncodeInfoFlags infoFlags = 0;
  OSStatus status = VTCompressionSessionEncodeFrame(self.session,
                                                    pixelBuffer,
                                                    presentationTime,
                                                    kCMTimeInvalid,
                                                    (__bridge CFDictionaryRef)frameProperties,
                                                    NULL,
                                                    &infoFlags);
  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:FBVideoEncoderErrorDomain
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot encode a frame (status %d)", (int)status]}];
    }
    return NO;
  }
  return YES;
}

- (void)requestKeyFrame
{
  self.forceNextKeyFrame = YES;
}

- (void)handleEncodedSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  BOOL isKeyFrame = [self.class isKeyFrameSampleBuffer:sampleBuffer];

  if (isKeyFrame) {
    NSData *parameterSets = [self extractParameterSetsFromSampleBuffer:sampleBuffer];
    if (nil != parameterSets) {
      self.parameterSetAnnexB = parameterSets;
    }
  }

  // Deliver picture (VCL) NAL units only; the delegate decides where the parameter sets go.
  NSData *pictureData = [self annexBPictureDataFromSampleBuffer:sampleBuffer];
  if (nil == pictureData || pictureData.length == 0) {
    return;
  }

  uint64_t presentationTimeUs = [self.class presentationTimeUsFromSampleBuffer:sampleBuffer];
  id<FBVideoEncoderDelegate> delegate = self.delegate;
  if (nil != delegate) {
    [delegate videoEncoder:self
            didEncodeFrame:pictureData
                isKeyFrame:isKeyFrame
        presentationTimeUs:presentationTimeUs];
  }
}

+ (uint64_t)presentationTimeUsFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  if (!CMTIME_IS_VALID(presentationTime)) {
    return 0;
  }
  CMTime microseconds = CMTimeConvertScale(presentationTime, 1000000, kCMTimeRoundingMethod_Default);
  if (microseconds.value < 0) {
    return 0;
  }
  return (uint64_t)microseconds.value;
}

+ (BOOL)isKeyFrameSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
  if (NULL == attachments || CFArrayGetCount(attachments) == 0) {
    // No attachments means the frame is not explicitly marked as non-sync, treat as key frame.
    return YES;
  }
  CFDictionaryRef attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
  return !CFDictionaryContainsKey(attachment, kCMSampleAttachmentKey_NotSync);
}

- (nullable NSData *)extractParameterSetsFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
  if (NULL == formatDescription) {
    return nil;
  }

  size_t parameterSetCount = 0;
  int nalUnitHeaderLength = 4;
  OSStatus status;
  if (self.codec == FBVideoCodecH265) {
    status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, 0, NULL, NULL,
                                                                &parameterSetCount, &nalUnitHeaderLength);
  } else {
    status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, 0, NULL, NULL,
                                                                &parameterSetCount, &nalUnitHeaderLength);
  }
  if (status != noErr || parameterSetCount == 0) {
    return nil;
  }
  self.nalUnitHeaderLength = (size_t)nalUnitHeaderLength;

  NSMutableData *parameterSets = [NSMutableData data];
  for (size_t index = 0; index < parameterSetCount; index++) {
    const uint8_t *parameterSetPointer = NULL;
    size_t parameterSetSize = 0;
    if (self.codec == FBVideoCodecH265) {
      status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDescription, index,
                                                                  &parameterSetPointer, &parameterSetSize, NULL, NULL);
    } else {
      status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, index,
                                                                  &parameterSetPointer, &parameterSetSize, NULL, NULL);
    }
    if (status == noErr && NULL != parameterSetPointer && parameterSetSize > 0) {
      [parameterSets appendBytes:FBAnnexBStartCode length:sizeof(FBAnnexBStartCode)];
      [parameterSets appendBytes:parameterSetPointer length:parameterSetSize];
    }
  }
  return parameterSets.length > 0 ? parameterSets : nil;
}

- (nullable NSData *)annexBPictureDataFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
  CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
  if (NULL == blockBuffer) {
    return nil;
  }
  size_t totalLength = CMBlockBufferGetDataLength(blockBuffer);
  if (totalLength == 0) {
    return nil;
  }

  NSMutableData *avccData = [NSMutableData dataWithLength:totalLength];
  OSStatus status = CMBlockBufferCopyDataBytes(blockBuffer, 0, totalLength, avccData.mutableBytes);
  if (status != kCMBlockBufferNoErr) {
    return nil;
  }

  const uint8_t *bytes = (const uint8_t *)avccData.bytes;
  size_t headerLength = self.nalUnitHeaderLength == 0 ? 4 : self.nalUnitHeaderLength;
  NSMutableData *annexBData = [NSMutableData data];
  size_t offset = 0;
  while (offset + headerLength <= totalLength) {
    uint64_t nalLength = 0;
    for (size_t i = 0; i < headerLength; i++) {
      nalLength = (nalLength << 8) | bytes[offset + i];
    }
    offset += headerLength;
    if (nalLength == 0 || offset + nalLength > totalLength) {
      break;
    }
    [annexBData appendBytes:FBAnnexBStartCode length:sizeof(FBAnnexBStartCode)];
    [annexBData appendBytes:bytes + offset length:(NSUInteger)nalLength];
    offset += nalLength;
  }
  return annexBData.length > 0 ? annexBData : nil;
}

- (void)stop
{
  if (NULL != self.session) {
    VTCompressionSessionCompleteFrames(self.session, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.session);
    CFRelease(self.session);
    self.session = NULL;
  }
}

- (void)dealloc
{
  [self stop];
}

@end
