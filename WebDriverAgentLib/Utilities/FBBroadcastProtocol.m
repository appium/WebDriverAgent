/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBroadcastProtocol.h"

const uint32_t FBBroadcastProtocolMagic = 0x57444142; // 'WDAB'
const uint8_t FBBroadcastProtocolVersion = 1;
const NSUInteger FBBroadcastHeaderLength = 16;
const uint16_t FBBroadcastDefaultControlPort = 9300;

const uint8_t FBBroadcastFrameFlagKeyFrame = 1 << 0;
const uint8_t FBBroadcastFrameOrientationShift = 1;
const uint8_t FBBroadcastFrameOrientationMask = 0x07;

NSString *const FBBroadcastKeyWidth = @"width";
NSString *const FBBroadcastKeyHeight = @"height";
NSString *const FBBroadcastKeyCodec = @"codec";
NSString *const FBBroadcastKeyBitrate = @"bitrate";
NSString *const FBBroadcastKeyFps = @"fps";
NSString *const FBBroadcastKeyProtocolVersion = @"protocolVersion";
NSString *const FBBroadcastKeyOsVersion = @"osVersion";
NSString *const FBBroadcastKeyState = @"state";
NSString *const FBBroadcastKeyFramesReceived = @"framesReceived";
NSString *const FBBroadcastKeyOrientation = @"orientation";
NSString *const FBBroadcastKeyScreenWidth = @"screenWidth";
NSString *const FBBroadcastKeyScreenHeight = @"screenHeight";
NSString *const FBBroadcastKeyEvent = @"event";
NSString *const FBBroadcastKeyReason = @"reason";
NSString *const FBBroadcastKeyMessage = @"message";

NSString *const FBBroadcastCodecH264 = @"h264";
NSString *const FBBroadcastCodecH265 = @"h265";

NSData *FBBroadcastEncodeMessage(FBBroadcastMessageType type,
                                 uint32_t sessionId,
                                 NSData *_Nullable payload)
{
  NSUInteger payloadLength = payload.length;
  NSMutableData *message = [NSMutableData dataWithCapacity:FBBroadcastHeaderLength + payloadLength];

  uint32_t bigMagic = CFSwapInt32HostToBig(FBBroadcastProtocolMagic);
  [message appendBytes:&bigMagic length:sizeof(bigMagic)];
  uint8_t version = FBBroadcastProtocolVersion;
  [message appendBytes:&version length:sizeof(version)];
  uint8_t messageType = (uint8_t)type;
  [message appendBytes:&messageType length:sizeof(messageType)];
  uint16_t reserved = 0;
  [message appendBytes:&reserved length:sizeof(reserved)];
  uint32_t bigSessionId = CFSwapInt32HostToBig(sessionId);
  [message appendBytes:&bigSessionId length:sizeof(bigSessionId)];
  uint32_t bigPayloadLength = CFSwapInt32HostToBig((uint32_t)payloadLength);
  [message appendBytes:&bigPayloadLength length:sizeof(bigPayloadLength)];

  if (payloadLength > 0) {
    [message appendData:(NSData *)payload];
  }
  return message;
}

NSData *_Nullable FBBroadcastEncodeJSONMessage(FBBroadcastMessageType type,
                                               uint32_t sessionId,
                                               NSDictionary<NSString *, id> *payload)
{
  NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:(NSJSONWritingOptions)0 error:NULL];
  if (nil == json) {
    return nil;
  }
  return FBBroadcastEncodeMessage(type, sessionId, json);
}

BOOL FBBroadcastParseHeader(NSData *headerData, FBBroadcastMessageHeader *outHeader)
{
  if (headerData.length < FBBroadcastHeaderLength) {
    return NO;
  }
  const uint8_t *bytes = (const uint8_t *)headerData.bytes;

  uint32_t magic;
  memcpy(&magic, bytes, sizeof(magic));
  if (CFSwapInt32BigToHost(magic) != FBBroadcastProtocolMagic) {
    return NO;
  }
  uint8_t version = bytes[4];
  if (version != FBBroadcastProtocolVersion) {
    return NO;
  }

  outHeader->version = version;
  outHeader->type = bytes[5];
  uint32_t sessionId;
  memcpy(&sessionId, bytes + 8, sizeof(sessionId));
  outHeader->sessionId = CFSwapInt32BigToHost(sessionId);
  uint32_t payloadLength;
  memcpy(&payloadLength, bytes + 12, sizeof(payloadLength));
  outHeader->payloadLength = CFSwapInt32BigToHost(payloadLength);
  return YES;
}

NSDictionary<NSString *, id> *_Nullable FBBroadcastParseJSONPayload(NSData *payload)
{
  if (payload.length == 0) {
    return nil;
  }
  id parsed = [NSJSONSerialization JSONObjectWithData:payload options:(NSJSONReadingOptions)0 error:NULL];
  return [parsed isKindOfClass:NSDictionary.class] ? parsed : nil;
}

NSData *FBBroadcastEncodeVideoFramePayload(uint64_t ptsUs,
                                           BOOL isKeyFrame,
                                           uint8_t orientation,
                                           NSData *annexBPictureData)
{
  NSMutableData *payload = [NSMutableData dataWithCapacity:sizeof(uint64_t) + sizeof(uint8_t) + annexBPictureData.length];
  uint64_t bigPts = CFSwapInt64HostToBig(ptsUs);
  [payload appendBytes:&bigPts length:sizeof(bigPts)];
  uint8_t flags = (isKeyFrame ? FBBroadcastFrameFlagKeyFrame : 0)
    | (uint8_t)((orientation & FBBroadcastFrameOrientationMask) << FBBroadcastFrameOrientationShift);
  [payload appendBytes:&flags length:sizeof(flags)];
  [payload appendData:annexBPictureData];
  return payload;
}

NSData *FBBroadcastEncodeVideoFrameMessage(uint32_t sessionId,
                                           uint64_t ptsUs,
                                           BOOL isKeyFrame,
                                           uint8_t orientation,
                                           NSData *annexBPictureData)
{
  static const NSUInteger prefixLength = sizeof(uint64_t) + sizeof(uint8_t);
  NSUInteger payloadLength = prefixLength + annexBPictureData.length;
  NSMutableData *message = [NSMutableData dataWithCapacity:FBBroadcastHeaderLength + payloadLength];

  uint32_t bigMagic = CFSwapInt32HostToBig(FBBroadcastProtocolMagic);
  [message appendBytes:&bigMagic length:sizeof(bigMagic)];
  uint8_t version = FBBroadcastProtocolVersion;
  [message appendBytes:&version length:sizeof(version)];
  uint8_t messageType = (uint8_t)FBBroadcastMessageTypeVideoFrame;
  [message appendBytes:&messageType length:sizeof(messageType)];
  uint16_t reserved = 0;
  [message appendBytes:&reserved length:sizeof(reserved)];
  uint32_t bigSessionId = CFSwapInt32HostToBig(sessionId);
  [message appendBytes:&bigSessionId length:sizeof(bigSessionId)];
  uint32_t bigPayloadLength = CFSwapInt32HostToBig((uint32_t)payloadLength);
  [message appendBytes:&bigPayloadLength length:sizeof(bigPayloadLength)];

  uint64_t bigPts = CFSwapInt64HostToBig(ptsUs);
  [message appendBytes:&bigPts length:sizeof(bigPts)];
  uint8_t flags = (isKeyFrame ? FBBroadcastFrameFlagKeyFrame : 0)
    | (uint8_t)((orientation & FBBroadcastFrameOrientationMask) << FBBroadcastFrameOrientationShift);
  [message appendBytes:&flags length:sizeof(flags)];
  [message appendData:annexBPictureData];
  return message;
}

BOOL FBBroadcastParseVideoFramePayload(NSData *payload,
                                       uint64_t *outPtsUs,
                                       BOOL *outIsKeyFrame,
                                       uint8_t *outOrientation,
                                       NSData *_Nullable __autoreleasing *_Nonnull outAnnexB)
{
  static const NSUInteger prefixLength = sizeof(uint64_t) + sizeof(uint8_t);
  if (payload.length < prefixLength) {
    return NO;
  }
  const uint8_t *bytes = (const uint8_t *)payload.bytes;
  uint64_t bigPts;
  memcpy(&bigPts, bytes, sizeof(bigPts));
  *outPtsUs = CFSwapInt64BigToHost(bigPts);
  uint8_t flags = bytes[sizeof(uint64_t)];
  *outIsKeyFrame = (flags & FBBroadcastFrameFlagKeyFrame) != 0;
  *outOrientation = (flags >> FBBroadcastFrameOrientationShift) & FBBroadcastFrameOrientationMask;
  *outAnnexB = [payload subdataWithRange:NSMakeRange(prefixLength, payload.length - prefixLength)];
  return YES;
}
