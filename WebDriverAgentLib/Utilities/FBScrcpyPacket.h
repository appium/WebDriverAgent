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
 The scrcpy packet framing shared by the video and audio capture streams:

   offset 0   8B  big-endian flags|pts (µs)
   offset 8   4B  big-endian payload length
   offset 12  ...  payload

 This is a wire contract with external consumers (e.g. ios-wired's scrcpy-bridge h264reader.go),
 matching scrcpy's own frame metadata (Streamer.writeFrameMeta in the scrcpy server).
 */

/** Bit 63: the payload is codec configuration (parameter sets / OpusHead), not media data. */
extern const uint64_t FBScrcpyFlagConfig;
/** Bit 62: the payload is a key (IDR) frame. */
extern const uint64_t FBScrcpyFlagKeyFrame;
/** The pts mask covering bits 0-61. */
extern const uint64_t FBScrcpyPtsMask;

/**
 Builds one scrcpy-framed packet.

 @param payload The packet payload (an Annex-B access unit, parameter sets or one Opus packet)
 @param flags FBScrcpyFlagConfig and/or FBScrcpyFlagKeyFrame; scrcpy itself sends config packets
              with a zero pts and no key-frame bit
 @param presentationTimeUs The presentation timestamp in microseconds (masked to bits 0-61)
 */
NSData *FBScrcpyPacketCreate(NSData *payload, uint64_t flags, uint64_t presentationTimeUs);

NS_ASSUME_NONNULL_END
