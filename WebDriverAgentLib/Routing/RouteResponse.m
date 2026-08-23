/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RouteResponse.h"

@interface RouteResponse ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mutableHeaders;
@end

@implementation RouteResponse

- (instancetype)init
{
  if ((self = [super init])) {
    _statusCode = kHTTPStatusCodeOK;
    _mutableHeaders = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSDictionary<NSString *, NSString *> *)headers
{
  return self.mutableHeaders.copy;
}

- (void)setHeader:(NSString *)field value:(NSString *)value
{
  self.mutableHeaders[field] = value;
}

- (void)respondWithData:(NSData *)data
{
  _responseData = data.copy;
  if (nil == self.mutableHeaders[@"Content-Length"]) {
    self.mutableHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)data.length];
  }
}

- (void)respondWithString:(NSString *)string
{
  [self respondWithString:string encoding:NSUTF8StringEncoding];
}

- (void)respondWithString:(NSString *)string encoding:(NSStringEncoding)encoding
{
  [self respondWithData:[string dataUsingEncoding:encoding] ?: [NSData data]];
}

@end
