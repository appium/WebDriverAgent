/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBRouteRequest-Private.h"

@implementation FBRouteRequest

+ (instancetype)routeRequestWithURL:(NSURL *)URL parameters:(NSDictionary *)parameters arguments:(NSDictionary *)arguments
{
  FBRouteRequest *request = [self.class new];
  request.URL = URL;
  request.parameters = parameters;
  request.arguments = arguments;
  return request;
}

+ (instancetype)routeRequestWithURL:(NSURL *)URL
                           parameters:(NSDictionary *)parameters
                             arguments:(NSDictionary *)arguments
                               session:(FBSession *)session
{
  FBRouteRequest *request = [self routeRequestWithURL:URL parameters:parameters arguments:arguments];
  request.session = session;
  return request;
}

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"Request URL %@ | Params %@ | Arguments %@",
    self.URL,
    self.parameters,
    self.arguments
  ];
}

@end
