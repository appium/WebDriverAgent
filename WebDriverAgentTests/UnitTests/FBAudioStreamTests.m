/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <AudioToolbox/AudioToolbox.h>

#import "FBBroadcastProtocol.h"

typedef struct {
  const float *samples;
  UInt32 totalFrames;
  UInt32 framesProvided;
  UInt32 channels;
} FBAudioStreamTestsFeedState;

static OSStatus FBAudioStreamTestsFeed(AudioConverterRef inConverter,
                                       UInt32 *ioNumberDataPackets,
                                       AudioBufferList *ioData,
                                       AudioStreamPacketDescription **outDescription,
                                       void *inUserData)
{
  FBAudioStreamTestsFeedState *state = (FBAudioStreamTestsFeedState *)inUserData;
  UInt32 available = state->totalFrames - state->framesProvided;
  if (available == 0) {
    *ioNumberDataPackets = 0;
    return 1; // out of data
  }
  UInt32 provide = MIN(*ioNumberDataPackets, available);
  ioData->mNumberBuffers = 1;
  ioData->mBuffers[0].mNumberChannels = state->channels;
  ioData->mBuffers[0].mData = (void *)(state->samples + (size_t)state->framesProvided * state->channels);
  ioData->mBuffers[0].mDataByteSize = provide * state->channels * sizeof(float);
  state->framesProvided += provide;
  *ioNumberDataPackets = provide;
  return noErr;
}

@interface FBAudioStreamTests : XCTestCase
@end

@implementation FBAudioStreamTests

// The OpusHead for mono/pre-skip 312/48 kHz must match the reference bytes documented in
// scrcpy's Streamer.fixOpusConfigPacket (the part it extracts as decoder extradata).
- (void)testOpusHeadMatchesScrcpyReferenceBytes
{
  const uint8_t expected[19] = {
    0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
    0x01,                                           // version
    0x01,                                           // channels
    0x38, 0x01,                                     // pre-skip 312 (LE)
    0x80, 0xBB, 0x00, 0x00,                         // input sample rate 48000 (LE)
    0x00, 0x00,                                     // output gain
    0x00,                                           // mapping family
  };
  NSData *head = FBBroadcastCreateOpusHead(1, 312, 48000);
  XCTAssertEqualObjects(head, [NSData dataWithBytes:expected length:sizeof(expected)]);
}

- (void)testOpusHeadFieldPlacement
{
  NSData *head = FBBroadcastCreateOpusHead(2, 0x0102, 44100);
  XCTAssertEqual(head.length, 19u);
  const uint8_t *bytes = (const uint8_t *)head.bytes;
  XCTAssertEqual(0, memcmp(bytes, "OpusHead", 8));
  XCTAssertEqual(bytes[8], 1);
  XCTAssertEqual(bytes[9], 2);
  // Little-endian fields.
  XCTAssertEqual(bytes[10], 0x02);
  XCTAssertEqual(bytes[11], 0x01);
  XCTAssertEqual(bytes[12], 0x44); // 44100 = 0x0000AC44
  XCTAssertEqual(bytes[13], 0xAC);
  XCTAssertEqual(bytes[14], 0x00);
  XCTAssertEqual(bytes[15], 0x00);
  XCTAssertEqual(bytes[18], 0);
}

- (void)testAudioFrameMessageRoundTrip
{
  NSData *packet = [@"opus-packet-bytes" dataUsingEncoding:NSUTF8StringEncoding];
  uint32_t sessionId = 3 | FBBroadcastAudioSessionIdFlag;
  NSData *message = FBBroadcastEncodeAudioFrameMessage(sessionId, 1234567, packet);

  FBBroadcastMessageHeader header;
  XCTAssertTrue(FBBroadcastParseHeader([message subdataWithRange:NSMakeRange(0, FBBroadcastHeaderLength)], &header));
  XCTAssertEqual(header.type, FBBroadcastMessageTypeAudioFrame);
  XCTAssertEqual(header.sessionId, sessionId);
  XCTAssertEqual(header.payloadLength, message.length - FBBroadcastHeaderLength);

  NSData *payload = [message subdataWithRange:NSMakeRange(FBBroadcastHeaderLength, header.payloadLength)];
  uint64_t ptsUs = 0;
  NSData *parsedPacket = nil;
  XCTAssertTrue(FBBroadcastParseAudioFramePayload(payload, &ptsUs, &parsedPacket));
  XCTAssertEqual(ptsUs, 1234567u);
  XCTAssertEqualObjects(parsedPacket, packet);
}

- (void)testAudioFramePayloadTooShortIsRejected
{
  uint64_t ptsUs = 0;
  NSData *packet = nil;
  XCTAssertFalse(FBBroadcastParseAudioFramePayload([NSData dataWithBytes:"short" length:5], &ptsUs, &packet));
}

- (void)testAudioSessionIdFlagDoesNotClipIdentifiers
{
  uint32_t wireId = (uint32_t)7 | FBBroadcastAudioSessionIdFlag;
  XCTAssertTrue(wireId & FBBroadcastAudioSessionIdFlag);
  XCTAssertEqual(wireId & ~FBBroadcastAudioSessionIdFlag, 7u);
}

// Drives the same AudioConverter configuration FBExtAudioPipeline uses, so an OS/SDK losing
// kAudioFormatOpus encode support fails loudly here instead of silently on a device.
- (void)testOpusEncoderProducesPackets
{
  const UInt32 sampleRate = 48000;
  const UInt32 channels = 2;

  AudioStreamBasicDescription inFormat = {0};
  inFormat.mSampleRate = sampleRate;
  inFormat.mFormatID = kAudioFormatLinearPCM;
  inFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
  inFormat.mChannelsPerFrame = channels;
  inFormat.mBitsPerChannel = 32;
  inFormat.mBytesPerFrame = channels * sizeof(float);
  inFormat.mFramesPerPacket = 1;
  inFormat.mBytesPerPacket = inFormat.mBytesPerFrame;

  AudioStreamBasicDescription outFormat = {0};
  outFormat.mSampleRate = sampleRate;
  outFormat.mFormatID = kAudioFormatOpus;
  outFormat.mChannelsPerFrame = channels;
  outFormat.mFramesPerPacket = 960;

  AudioConverterRef converter = NULL;
  OSStatus status = AudioConverterNew(&inFormat, &outFormat, &converter);
  XCTAssertEqual(status, noErr, @"kAudioFormatOpus encoding is unavailable");
  if (status != noErr) {
    return;
  }

  NSMutableData *pcm = [NSMutableData dataWithLength:sampleRate * channels * sizeof(float)];
  float *samples = (float *)pcm.mutableBytes;
  for (UInt32 i = 0; i < sampleRate; i++) {
    float value = sinf(2.0f * (float)M_PI * 440.0f * (float)i / (float)sampleRate) * 0.5f;
    samples[i * channels] = value;
    samples[i * channels + 1] = value;
  }
  FBAudioStreamTestsFeedState state = { samples, sampleRate, 0, channels };

  NSMutableData *packetBuffer = [NSMutableData dataWithLength:1500];
  NSUInteger packets = 0;
  for (;;) {
    AudioBufferList outList = {0};
    outList.mNumberBuffers = 1;
    outList.mBuffers[0].mNumberChannels = channels;
    outList.mBuffers[0].mData = packetBuffer.mutableBytes;
    outList.mBuffers[0].mDataByteSize = (UInt32)packetBuffer.length;
    AudioStreamPacketDescription description = {0};
    UInt32 packetCount = 1;
    status = AudioConverterFillComplexBuffer(converter, FBAudioStreamTestsFeed, &state,
                                             &packetCount, &outList, &description);
    if (packetCount == 0) {
      break;
    }
    packets += 1;
    XCTAssertGreaterThan(description.mDataByteSize > 0 ? description.mDataByteSize : outList.mBuffers[0].mDataByteSize, 0u);
    if (status != noErr) {
      break;
    }
  }
  AudioConverterDispose(converter);
  // 48000 frames at 960 frames per packet.
  XCTAssertEqualWithAccuracy((double)packets, 50.0, 2.0);
}

@end
