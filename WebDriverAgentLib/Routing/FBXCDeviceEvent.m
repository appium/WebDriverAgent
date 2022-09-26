/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCDeviceEvent.h"

#import "FBErrorBuilder.h"

id<FBXCDeviceEvent> FBCreateXCDeviceEvent(unsigned int page,
                                          unsigned int usage,
                                          double duration,
                                          NSError **error)
{
  Class xcDeviceEventClass = NSClassFromString(@"XCDeviceEvent");
  if (nil == xcDeviceEventClass) {
    [[[FBErrorBuilder builder]
      withDescription:@"Cannot find XCDeviceEvent class"]
     buildError:error];
    return nil;
  }
  SEL deviceEventFactorySelector = NSSelectorFromString(@"deviceEventWithPage:usage:duration:");
  if (![xcDeviceEventClass respondsToSelector:deviceEventFactorySelector]) {
    [[[FBErrorBuilder builder]
      withDescription:@"'deviceEventWithPage:usage:duration:' factory method is not found on XCDeviceEvent class"]
     buildError:error];
    return nil;
  }
  NSMethodSignature *deviceEventFactorySignature = [xcDeviceEventClass methodSignatureForSelector:deviceEventFactorySelector];
  NSInvocation *deviceEventFactoryInvocation = [NSInvocation invocationWithMethodSignature:deviceEventFactorySignature];
  [deviceEventFactoryInvocation setSelector:deviceEventFactorySelector];
  [deviceEventFactoryInvocation setArgument:&page atIndex:2];
  [deviceEventFactoryInvocation setArgument:&usage atIndex:3];
  [deviceEventFactoryInvocation setArgument:&duration atIndex:4];
  [deviceEventFactoryInvocation invokeWithTarget:xcDeviceEventClass];
  id<FBXCDeviceEvent> __unsafe_unretained instance;
  [deviceEventFactoryInvocation getReturnValue:&instance];
  return instance;
}
