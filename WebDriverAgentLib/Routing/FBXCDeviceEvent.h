/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FBXCDeviceEvent

@property unsigned long long type; // @synthesize type=_type;
@property double rotation; // @synthesize rotation=_rotation;
@property double duration; // @synthesize duration=_duration;
@property unsigned int usage; // @synthesize usage=_usage;
@property unsigned int eventPage; // @synthesize eventPage=_eventPage;
@property(readonly) BOOL isButtonHoldEvent;

+ (id)deviceEventForDigitalCrownRotation:(double)arg1 velocity:(double)arg2;
+ (id)deviceEventWithPage:(unsigned int)arg1 usage:(unsigned int)arg2 duration:(double)arg3;

- (void)dispatch;

@end

_Nullable id<FBXCDeviceEvent> FBCreateXCDeviceEvent(unsigned int page,
                                                    unsigned int usage,
                                                    double duration,
                                                    NSError **error);

NS_ASSUME_NONNULL_END
