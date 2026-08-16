/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBWatchHTTPServer.h"

#import "FBConfiguration.h"
#import "FBTCPSocket.h"

static NSData *FBCRLFCRLFData(void)
{
  static NSData *data;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    data = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
  });
  return data;
}

// -dataUsingEncoding:NSUTF8StringEncoding never actually returns nil; this just keeps the cast
// out of every call site below.
static NSData * _Nonnull FBUTF8Data(NSString *string)
{
  return (NSData * _Nonnull)[string dataUsingEncoding:NSUTF8StringEncoding];
}

@interface FBWatchHTTPRoute : NSObject
@property (nonatomic, copy) NSString *verb;
@property (nonatomic, strong) NSRegularExpression *regex;
@property (nonatomic, copy, nullable) NSArray<NSString *> *keys;
@property (nonatomic, copy) void (^block)(RouteRequest *request, RouteResponse *response);
@end

@implementation FBWatchHTTPRoute
@end


@interface FBWatchHTTPServer () <FBTCPSocketDelegate>

@property (nonatomic, nullable, strong) FBTCPSocket *socket;
@property (nonatomic, strong) NSMutableArray<FBWatchHTTPRoute *> *routes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *defaultHeaders;
@property (nonatomic, nullable) dispatch_queue_t routeQueue;
// nw_connection_t isn't NSCopying, so it can't be an NSDictionary key - use NSMapTable instead.
@property (nonatomic, strong) NSMapTable<id, NSMutableData *> *connectionBuffers;

@end

@implementation FBWatchHTTPServer

- (instancetype)init
{
  if ((self = [super init])) {
    _routes = [NSMutableArray array];
    _defaultHeaders = [NSMutableDictionary dictionary];
    _connectionBuffers = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOptions)(NSMapTableObjectPointerPersonality | NSMapTableStrongMemory)
                                                 valueOptions:(NSPointerFunctionsOptions)NSMapTableStrongMemory];
  }
  return self;
}

- (void)setRouteQueue:(nullable dispatch_queue_t)queue
{
  _routeQueue = queue;
}

- (void)setDefaultHeader:(NSString *)field value:(NSString *)value
{
  self.defaultHeaders[field] = value;
}

#pragma mark - Route registration

- (FBWatchHTTPRoute *)compiledRouteWithPath:(NSString *)path
{
  FBWatchHTTPRoute *route = [FBWatchHTTPRoute new];
  NSMutableArray<NSString *> *keys = [NSMutableArray array];

  // Escape regex-significant characters before substituting :param placeholders, like
  // RoutingHTTPServer.m does.
  NSRegularExpression *escapeRegex = [NSRegularExpression regularExpressionWithPattern:@"[.+()]"
                                                                                options:(NSRegularExpressionOptions)0
                                                                                  error:nil];
  NSString *escapedPath = [escapeRegex stringByReplacingMatchesInString:path
                                                                  options:(NSMatchingOptions)0
                                                                    range:NSMakeRange(0, path.length)
                                                             withTemplate:@"\\\\$0"];

  NSRegularExpression *paramRegex = [NSRegularExpression regularExpressionWithPattern:@"(:(\\w+)|\\*)"
                                                                               options:(NSRegularExpressionOptions)0
                                                                                 error:nil];
  NSMutableString *regexPath = [NSMutableString stringWithString:escapedPath];
  __block NSInteger diff = 0;
  [paramRegex enumerateMatchesInString:escapedPath
                                options:(NSMatchingOptions)0
                                  range:NSMakeRange(0, escapedPath.length)
                             usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
    NSRange replacementRange = NSMakeRange(diff + result.range.location, result.range.length);
    NSString *capturedString = [escapedPath substringWithRange:result.range];
    NSString *replacementString;
    if ([capturedString isEqualToString:@"*"]) {
      [keys addObject:@"wildcards"];
      replacementString = @"(.*?)";
    } else {
      NSString *keyString = [escapedPath substringWithRange:[result rangeAtIndex:2]];
      [keys addObject:keyString];
      replacementString = @"([^/]+)";
    }
    [regexPath replaceCharactersInRange:replacementRange withString:replacementString];
    diff += replacementString.length - result.range.length;
  }];

  NSString *anchoredPattern = [NSString stringWithFormat:@"^%@$", regexPath];
  route.regex = [NSRegularExpression regularExpressionWithPattern:anchoredPattern
                                                            options:NSRegularExpressionCaseInsensitive
                                                              error:nil];
  route.keys = keys.count > 0 ? keys.copy : nil;
  return route;
}

- (void)handleMethod:(NSString *)method
            withPath:(NSString *)path
               block:(void (^)(RouteRequest *request, RouteResponse *response))block
{
  FBWatchHTTPRoute *route = [self compiledRouteWithPath:path];
  route.verb = method.uppercaseString;
  route.block = block;
  [self.routes addObject:route];
}

- (void)get:(NSString *)path withBlock:(void (^)(RouteRequest *request, RouteResponse *response))block
{
  [self handleMethod:@"GET" withPath:path block:block];
}

#pragma mark - Lifecycle

- (BOOL)start:(NSError **)error
{
  FBTCPSocket *socket = [[FBTCPSocket alloc] initWithPort:self.port];
  socket.delegate = self;
  if (![socket startWithError:error]) {
    return NO;
  }
  self.socket = socket;
  _isRunning = YES;
  return YES;
}

- (void)stop:(BOOL)immediately
{
  [self.socket stop];
  self.socket = nil;
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeAllObjects];
  }
  _isRunning = NO;
}

#pragma mark - FBTCPSocketDelegate

- (void)didClientConnect:(nw_connection_t)newClient
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers setObject:[NSMutableData data] forKey:newClient];
  }
}

- (void)didClientDisconnect:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
  }
}

- (void)client:(nw_connection_t)client didReceiveData:(NSData *)data
{
  NSMutableData *buffer;
  @synchronized (self.connectionBuffers) {
    buffer = [self.connectionBuffers objectForKey:client];
    if (nil == buffer) {
      return;
    }
    [buffer appendData:data];
  }
  [self processBufferForClient:client];
}

#pragma mark - HTTP parsing

- (void)processBufferForClient:(nw_connection_t)client
{
  while (YES) {
    NSMutableData *buffer;
    @synchronized (self.connectionBuffers) {
      buffer = [self.connectionBuffers objectForKey:client];
    }
    if (nil == buffer) {
      return;
    }

    NSRange headerEndRange = [buffer rangeOfData:FBCRLFCRLFData() options:(NSDataSearchOptions)0 range:NSMakeRange(0, buffer.length)];
    if (NSNotFound == headerEndRange.location) {
      return;
    }

    NSData *headerData = [buffer subdataWithRange:NSMakeRange(0, headerEndRange.location)];
    NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [headerString componentsSeparatedByString:@"\r\n"];
    if (lines.count < 1) {
      [self closeClient:client];
      return;
    }

    NSArray<NSString *> *requestLineParts = [lines.firstObject componentsSeparatedByString:@" "];
    if (requestLineParts.count < 2) {
      [self closeClient:client];
      return;
    }
    NSString *method = requestLineParts[0].uppercaseString;
    NSString *pathAndQuery = requestLineParts[1];

    NSMutableDictionary<NSString *, NSString *> *requestHeaders = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lines.count; i++) {
      NSString *line = lines[i];
      NSRange colonRange = [line rangeOfString:@":"];
      if (NSNotFound == colonRange.location) {
        continue;
      }
      NSString *name = [line substringToIndex:colonRange.location];
      NSString *value = [[line substringFromIndex:colonRange.location + 1]
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
      requestHeaders[name.lowercaseString] = value;
    }

    NSUInteger contentLength = (NSUInteger)requestHeaders[@"content-length"].integerValue;
    if (contentLength > FBConfiguration.sharedInstance.httpRequestBodySizeLimit) {
      // Mirrors FBHTTPConnection's maxRequestBodySize enforcement on iOS/tvOS. Closes the
      // connection after responding, since the rest of the oversized body is still incoming.
      RouteResponse *tooLarge = [RouteResponse new];
      tooLarge.statusCode = kHTTPStatusCodeRequestEntityTooLarge;
      [tooLarge respondWithString:@"Request Entity Too Large"];
      [self writeResponse:tooLarge toClient:client thenCloseConnection:YES];
      return;
    }
    NSUInteger bodyStart = headerEndRange.location + headerEndRange.length;
    NSUInteger totalRequestLength = bodyStart + contentLength;
    if (buffer.length < totalRequestLength) {
      // Wait for the rest of the body to arrive.
      return;
    }

    NSData *body = contentLength > 0 ? [buffer subdataWithRange:NSMakeRange(bodyStart, contentLength)] : [NSData data];

    @synchronized (self.connectionBuffers) {
      [buffer replaceBytesInRange:NSMakeRange(0, totalRequestLength) withBytes:NULL length:0];
    }

    [self dispatchMethod:method pathAndQuery:pathAndQuery body:body client:client];
  }
}

- (void)dispatchMethod:(NSString *)method pathAndQuery:(NSString *)pathAndQuery body:(NSData *)body client:(nw_connection_t)client
{
  NSURLComponents *requestTarget = [NSURLComponents componentsWithString:pathAndQuery];
  NSString *path = requestTarget.path ?: pathAndQuery;

  for (FBWatchHTTPRoute *route in self.routes) {
    if (![route.verb isEqualToString:method]) {
      continue;
    }
    NSTextCheckingResult *result = [route.regex firstMatchInString:path options:(NSMatchingOptions)0 range:NSMakeRange(0, path.length)];
    if (nil == result) {
      continue;
    }

    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *queryItem in requestTarget.queryItems) {
      params[queryItem.name] = queryItem.value ?: @"";
    }
    if (route.keys.count > 0 && result.numberOfRanges == route.keys.count + 1) {
      NSUInteger index = 1;
      for (NSString *key in route.keys) {
        params[key] = [path substringWithRange:[result rangeAtIndex:index]];
        index++;
      }
    }

    NSURL *url = [NSURL URLWithString:path] ?: [NSURL URLWithString:@"/"];
    RouteRequest *request = [[RouteRequest alloc] initWithURL:url params:params.copy body:body];
    RouteResponse *response = [RouteResponse new];
    [self.defaultHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
      [response setHeader:field value:value];
    }];

    void (^invoke)(void) = ^{
      route.block(request, response);
      [self writeResponse:response toClient:client];
    };
    dispatch_queue_t routeQueue = self.routeQueue;
    if (routeQueue) {
      dispatch_async((dispatch_queue_t _Nonnull)routeQueue, invoke);
    } else {
      invoke();
    }
    return;
  }

  RouteResponse *notFound = [RouteResponse new];
  notFound.statusCode = kHTTPStatusCodeNotFound;
  [notFound respondWithString:@"Not Found"];
  [self writeResponse:notFound toClient:client];
}

- (void)writeResponse:(RouteResponse *)response toClient:(nw_connection_t)client
{
  [self writeResponse:response toClient:client thenCloseConnection:NO];
}

- (void)writeResponse:(RouteResponse *)response toClient:(nw_connection_t)client thenCloseConnection:(BOOL)shouldClose
{
  NSMutableData *payload = [NSMutableData data];
  NSString *statusLine = [NSString stringWithFormat:@"HTTP/1.1 %ld %@\r\n",
                           (long)response.statusCode, [self reasonPhraseForStatusCode:response.statusCode]];
  [payload appendData:FBUTF8Data(statusLine)];

  NSData *body = response.responseData ?: [NSData data];
  NSMutableDictionary<NSString *, NSString *> *headers = response.headers.mutableCopy;
  if (nil == headers[@"Content-Length"]) {
    headers[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
  }
  [headers enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
    NSString *headerLine = [NSString stringWithFormat:@"%@: %@\r\n", field, value];
    [payload appendData:FBUTF8Data(headerLine)];
  }];
  [payload appendData:FBUTF8Data(@"\r\n")];
  [payload appendData:body];

  if (shouldClose) {
    __weak typeof(self) weakSelf = self;
    [self.socket writeData:payload toClient:client completion:^{
      [weakSelf closeClient:client];
    }];
  } else {
    [self.socket writeData:payload toClient:client];
  }
}

- (void)closeClient:(nw_connection_t)client
{
  @synchronized (self.connectionBuffers) {
    [self.connectionBuffers removeObjectForKey:client];
  }
  nw_connection_cancel(client);
}

- (NSString *)reasonPhraseForStatusCode:(HTTPStatusCode)statusCode
{
  // if/else, not switch, to avoid having to list all ~90 HTTPStatusCode cases for -Wswitch-enum.
  if (kHTTPStatusCodeOK == statusCode) {
    return @"OK";
  } else if (kHTTPStatusCodeBadRequest == statusCode) {
    return @"Bad Request";
  } else if (kHTTPStatusCodeNotFound == statusCode) {
    return @"Not Found";
  } else if (kHTTPStatusCodeInternalServerError == statusCode) {
    return @"Internal Server Error";
  }
  return @"Status";
}

@end
