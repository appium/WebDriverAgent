/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RouteRequest.h"

@implementation RouteRequest

- (instancetype)initWithURL:(NSURL *)url
                      params:(NSDictionary<NSString *, NSString *> *)params
                        body:(NSData *)body
{
  if ((self = [super init])) {
    _url = url.copy;
    _params = params.copy;
    _body = body.copy;
  }
  return self;
}

@end
