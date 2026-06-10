/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <ReplayKit/ReplayKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The broadcast upload extension's principal class: receives the system screen frames from
 ReplayKit and forwards them to the per-session encode pipelines managed by
 FBExtBroadcastClient. Audio samples are ignored (audio capture is a planned follow-up).
 */
@interface FBBroadcastSampleHandler : RPBroadcastSampleHandler

@end

NS_ASSUME_NONNULL_END
