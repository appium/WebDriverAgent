/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenRecordingRequest.h"

#import "FBErrorBuilder.h"
#import "XCUIScreen.h"

@implementation FBScreenRecordingRequest

- (instancetype)initWithFps:(NSUInteger)fps codec:(long long)codec
{
  if ((self = [super init])) {
    _fps = fps;
    _codec = codec;
  }
  return self;
}

- (nullable id)createVideoEncodingWithError:(NSError **)error
{
  Class videoEncodingClass = NSClassFromString(@"XCTVideoEncoding");
  if (nil == videoEncodingClass) {
    [[[FBErrorBuilder builder]
      withDescription:@"Cannot find XCTVideoEncoding class"]
     buildError:error];
    return nil;
  }

  id videoEncodingAllocated = [videoEncodingClass alloc];
  SEL videoEncodingConstructorSelector = NSSelectorFromString(@"initWithCodec:frameRate:");
  if (![videoEncodingAllocated respondsToSelector:videoEncodingConstructorSelector]) {
    [[[FBErrorBuilder builder]
      withDescription:@"'initWithCodec:frameRate:' contructor is not found on XCTVideoEncoding class"]
     buildError:error];
    return nil;
  }

  NSMethodSignature *videoEncodingContructorSignature = [videoEncodingAllocated methodSignatureForSelector:videoEncodingConstructorSelector];
  NSInvocation *videoEncodingInitInvocation = [NSInvocation invocationWithMethodSignature:videoEncodingContructorSignature];
  [videoEncodingInitInvocation setSelector:videoEncodingConstructorSelector];
  long long codec = self.codec;
  [videoEncodingInitInvocation setArgument:&codec atIndex:2];
  double frameRate = self.fps;
  [videoEncodingInitInvocation setArgument:&frameRate atIndex:3];
  [videoEncodingInitInvocation invokeWithTarget:videoEncodingAllocated];
  id __unsafe_unretained result;
  [videoEncodingInitInvocation getReturnValue:&result];
  return result;
}

- (id)toNativeRequestWithError:(NSError **)error
{
  Class screenRecordingRequestClass = NSClassFromString(@"XCTScreenRecordingRequest");
  if (nil == screenRecordingRequestClass) {
    [[[FBErrorBuilder builder]
      withDescription:@"Cannot find XCTScreenRecordingRequest class"]
     buildError:error];
    return nil;
  }

  id screenRecordingRequestAllocated = [screenRecordingRequestClass alloc];
  SEL screenRecordingRequestConstructorSelector = NSSelectorFromString(@"initWithScreenID:rect:preferredEncoding:");
  if (![screenRecordingRequestAllocated respondsToSelector:screenRecordingRequestConstructorSelector]) {
    [[[FBErrorBuilder builder]
      withDescription:@"'initWithScreenID:rect:preferredEncoding:' contructor is not found on XCTScreenRecordingRequest class"]
     buildError:error];
    return nil;
  }
  id videoEncoding = [self createVideoEncodingWithError:error];
  if (nil == videoEncoding) {
    return nil;
  }

  NSMethodSignature *screenRecordingRequestContructorSignature = [screenRecordingRequestAllocated methodSignatureForSelector:screenRecordingRequestConstructorSelector];
  NSInvocation *screenRecordingRequestInitInvocation = [NSInvocation invocationWithMethodSignature:screenRecordingRequestContructorSignature];
  [screenRecordingRequestInitInvocation setSelector:screenRecordingRequestConstructorSelector];
  long long mainScreenId = XCUIScreen.mainScreen.displayID;
  [screenRecordingRequestInitInvocation setArgument:&mainScreenId atIndex:2];
  CGRect fullScreenRect = CGRectNull;
  [screenRecordingRequestInitInvocation setArgument:&fullScreenRect atIndex:3];
  [screenRecordingRequestInitInvocation setArgument:&videoEncoding atIndex:4];
  [screenRecordingRequestInitInvocation invokeWithTarget:screenRecordingRequestAllocated];
  id __unsafe_unretained result;
  [screenRecordingRequestInitInvocation getReturnValue:&result];
  return result;
}

@end
