/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Wire protocol shared between WebDriverAgent and the ReplayKit broadcast upload extension.

 This file is compiled into both WebDriverAgentLib and the WebDriverAgentBroadcast extension
 target, so it must only depend on Foundation.

 Transport: a single TCP connection on loopback. The extension is the client, WDA is the
 server. Every message is a fixed 16-byte big-endian header followed by a payload:

   offset 0  uint32  magic = 'WDAB'
   offset 4  uint8   protocolVersion
   offset 5  uint8   messageType
   offset 6  uint16  reserved (0)
   offset 8  uint32  sessionId (0 when not applicable)
   offset 12 uint32  payloadLength
   offset 16 ...     payload

 Control payloads are UTF-8 JSON; the high-rate VIDEO_FRAME payload is fixed binary
 (see FBBroadcastEncodeVideoFramePayload).
 */

/** 'WDAB' */
extern const uint32_t FBBroadcastProtocolMagic;
extern const uint8_t FBBroadcastProtocolVersion;
/** The fixed message header length in bytes. */
extern const NSUInteger FBBroadcastHeaderLength;
/** The loopback TCP port WDA listens on for the extension connection. */
extern const uint16_t FBBroadcastDefaultControlPort;

typedef NS_ENUM(uint8_t, FBBroadcastMessageType) {
  // WDA -> extension
  /** JSON {width, height, codec, bitrate, fps}; sessionId in the header. */
  FBBroadcastMessageTypeSessionAdd = 0x01,
  /** Empty payload; sessionId in the header. */
  FBBroadcastMessageTypeSessionRemove = 0x02,
  /** Empty payload; sessionId in the header. */
  FBBroadcastMessageTypeKeyframeRequest = 0x03,
  /** Empty payload. Asks the extension to finish the broadcast. */
  FBBroadcastMessageTypeStopBroadcast = 0x04,

  // extension -> WDA
  /** JSON {protocolVersion, osVersion}. Sent once right after connecting. */
  FBBroadcastMessageTypeHello = 0x81,
  /** JSON {state, framesReceived, orientation, screenWidth, screenHeight}. Sent every 2s. */
  FBBroadcastMessageTypeHeartbeat = 0x82,
  /** Raw Annex-B parameter sets (VPS/SPS/PPS) for sessionId. Sent before the IDR that uses them. */
  FBBroadcastMessageTypeVideoParams = 0x83,
  /** Binary: [8B ptsUs BE][1B flags][Annex-B VCL NAL units]; sessionId in the header. */
  FBBroadcastMessageTypeVideoFrame = 0x84,
  /** JSON {event: "paused"|"resumed"|"finishing", reason}. */
  FBBroadcastMessageTypeStatus = 0x85,
  /** JSON {message} for sessionId (e.g. the per-session encoder could not be created). */
  FBBroadcastMessageTypeSessionError = 0x86,
  /**
   The RFC 7845 OpusHead identification header (19 bytes, mapping family 0) for sessionId.
   Sent right after the audio pipeline's encoder is created and again whenever its parameters
   change. Sent before the first AUDIO_FRAME that uses it.
   */
  FBBroadcastMessageTypeAudioParams = 0x87,
  /** Binary: [8B ptsUs BE][one Opus packet]; sessionId in the header. */
  FBBroadcastMessageTypeAudioFrame = 0x88,
};

/** A parsed message header. */
typedef struct {
  uint8_t version;
  uint8_t type;
  uint32_t sessionId;
  uint32_t payloadLength;
} FBBroadcastMessageHeader;

/** VIDEO_FRAME flags bit 0: the frame is a key (IDR) frame. */
extern const uint8_t FBBroadcastFrameFlagKeyFrame;
/** VIDEO_FRAME flags bits 1-3: CGImagePropertyOrientation (1-8) of the captured frame. */
extern const uint8_t FBBroadcastFrameOrientationShift;
extern const uint8_t FBBroadcastFrameOrientationMask;

/**
 Bit 31 of the wire sessionId marks an audio session. SESSION_REMOVE and KEYFRAME_REQUEST carry
 nothing but a sessionId, and the extension replaces same-id pipelines on SESSION_ADD, so audio
 and video ids must stay disjoint on the wire. The HTTP-visible id is sessionId without the flag.
 */
extern const uint32_t FBBroadcastAudioSessionIdFlag;

/** JSON keys for SESSION_ADD / HELLO / HEARTBEAT / STATUS payloads. */
extern NSString *const FBBroadcastKeyWidth;
extern NSString *const FBBroadcastKeyHeight;
extern NSString *const FBBroadcastKeyCodec;
extern NSString *const FBBroadcastKeyBitrate;
extern NSString *const FBBroadcastKeyFps;
extern NSString *const FBBroadcastKeyProtocolVersion;
extern NSString *const FBBroadcastKeyOsVersion;
extern NSString *const FBBroadcastKeyState;
extern NSString *const FBBroadcastKeyFramesReceived;
extern NSString *const FBBroadcastKeyOrientation;
extern NSString *const FBBroadcastKeyScreenWidth;
extern NSString *const FBBroadcastKeyScreenHeight;
extern NSString *const FBBroadcastKeyEvent;
extern NSString *const FBBroadcastKeyReason;
extern NSString *const FBBroadcastKeyMessage;
/** SESSION_ADD media discriminator: "audio" marks an audio session; absent means video. */
extern NSString *const FBBroadcastKeyMedia;
extern NSString *const FBBroadcastKeyChannels;
extern NSString *const FBBroadcastKeySampleRate;

/** The FBBroadcastKeyMedia value marking an audio session. */
extern NSString *const FBBroadcastMediaAudio;

/** Codec string values used in SESSION_ADD, matching the HTTP API. */
extern NSString *const FBBroadcastCodecH264;
extern NSString *const FBBroadcastCodecH265;
extern NSString *const FBBroadcastCodecOpus;

/** Builds a complete wire message (header + payload). */
NSData *FBBroadcastEncodeMessage(FBBroadcastMessageType type,
                                 uint32_t sessionId,
                                 NSData *_Nullable payload);

/** Builds a complete wire message with a JSON payload. Returns nil if serialization fails. */
NSData *_Nullable FBBroadcastEncodeJSONMessage(FBBroadcastMessageType type,
                                               uint32_t sessionId,
                                               NSDictionary<NSString *, id> *payload);

/**
 Parses and validates a 16-byte header.

 @return NO when the data is too short, the magic does not match or the version is unsupported.
 */
BOOL FBBroadcastParseHeader(NSData *headerData, FBBroadcastMessageHeader *outHeader);

/** Deserializes a JSON control payload. Returns nil when the payload is not a JSON object. */
NSDictionary<NSString *, id> *_Nullable FBBroadcastParseJSONPayload(NSData *payload);

/** Builds a VIDEO_FRAME payload: [8B ptsUs BE][1B flags][annexB]. */
NSData *FBBroadcastEncodeVideoFramePayload(uint64_t ptsUs,
                                           BOOL isKeyFrame,
                                           uint8_t orientation,
                                           NSData *annexBPictureData);

/** Builds a complete VIDEO_FRAME wire message without first materializing a separate payload. */
NSData *FBBroadcastEncodeVideoFrameMessage(uint32_t sessionId,
                                           uint64_t ptsUs,
                                           BOOL isKeyFrame,
                                           uint8_t orientation,
                                           NSData *annexBPictureData);

/**
 Parses a VIDEO_FRAME payload.

 @return NO when the payload is shorter than its fixed prefix.
 */
BOOL FBBroadcastParseVideoFramePayload(NSData *payload,
                                       uint64_t *outPtsUs,
                                       BOOL *outIsKeyFrame,
                                       uint8_t *outOrientation,
                                       NSData *_Nullable __autoreleasing *_Nonnull outAnnexB);

/** Builds a complete AUDIO_FRAME wire message: header + [8B ptsUs BE][opusPacket]. */
NSData *FBBroadcastEncodeAudioFrameMessage(uint32_t sessionId,
                                           uint64_t ptsUs,
                                           NSData *opusPacket);

/**
 Parses an AUDIO_FRAME payload.

 @return NO when the payload is shorter than its fixed prefix.
 */
BOOL FBBroadcastParseAudioFramePayload(NSData *payload,
                                       uint64_t *outPtsUs,
                                       NSData *_Nullable __autoreleasing *_Nonnull outOpusPacket);

/**
 Builds the 19-byte RFC 7845 OpusHead identification header (channel mapping family 0).
 Unlike the big-endian framing around it, the OpusHead's own fields are little-endian:

   offset 0   8B  ASCII "OpusHead"
   offset 8   1B  version = 1
   offset 9   1B  channel count
   offset 10  2B  pre-skip in 48 kHz samples (LE)
   offset 12  4B  input sample rate in Hz, informational (LE)
   offset 16  2B  output gain, Q7.8 (LE) = 0
   offset 18  1B  channel mapping family = 0
 */
NSData *FBBroadcastCreateOpusHead(uint8_t channelCount,
                                  uint16_t preSkip,
                                  uint32_t inputSampleRate);

NS_ASSUME_NONNULL_END
