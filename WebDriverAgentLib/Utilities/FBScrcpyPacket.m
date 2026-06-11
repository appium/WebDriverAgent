/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScrcpyPacket.h"

const uint64_t FBScrcpyFlagConfig   = (uint64_t)1 << 63;
const uint64_t FBScrcpyFlagKeyFrame = (uint64_t)1 << 62;
const uint64_t FBScrcpyPtsMask      = ~((uint64_t)3 << 62);

NSData *FBScrcpyPacketCreate(NSData *payload, uint64_t flags, uint64_t presentationTimeUs)
{
  uint64_t ptsAndFlags = flags | (presentationTimeUs & FBScrcpyPtsMask);
  uint8_t header[12];
  uint64_t bigPtsAndFlags = CFSwapInt64HostToBig(ptsAndFlags);
  memcpy(header, &bigPtsAndFlags, sizeof(bigPtsAndFlags));
  uint32_t bigSize = CFSwapInt32HostToBig((uint32_t)payload.length);
  memcpy(header + sizeof(bigPtsAndFlags), &bigSize, sizeof(bigSize));

  NSMutableData *packet = [NSMutableData dataWithCapacity:sizeof(header) + payload.length];
  [packet appendBytes:header length:sizeof(header)];
  [packet appendData:payload];
  return packet;
}
