#import "HTTPMessage.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#pragma clang diagnostic ignored "-Wdirect-ivar-access"

@implementation HTTPMessage

- (id)init
{
  if ((self = [super init]))
  {
    _headers = [[NSMutableDictionary alloc] init];
    _body = [[NSMutableData alloc] init];
    _rawData = [[NSMutableData alloc] init];
    _version = HTTPVersion1_1;
    _headerComplete = NO;
    _isRequest = YES;
  }
  return self;
}

- (id)initEmptyRequest
{
  if ((self = [self init]))
  {
    _isRequest = YES;
  }
  return self;
}

- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version
{
  if ((self = [self init]))
  {
    _isRequest = YES;
    _method = [method copy];
    _url = [url copy];
    _version = version ? [version copy] : HTTPVersion1_1;
  }
  return self;
}

- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version
{
  if ((self = [self init]))
  {
    _isRequest = NO;
    _statusCode = code;
    _statusDescription = [description copy];
    _version = version ? [version copy] : HTTPVersion1_1;
  }
  return self;
}

- (BOOL)appendData:(NSData *)data
{
  if (!data || [data length] == 0)
  {
    return NO;
  }

  [_rawData appendData:data];

  if (!_headerComplete)
  {
    // Look for the end of headers (CRLF CRLF or LF LF)
    NSData *headerEndMarker = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    NSRange headerEndRange = [_rawData rangeOfData:headerEndMarker options:0 range:NSMakeRange(0, [_rawData length])];

    if (headerEndRange.location == NSNotFound)
    {
      // Also check for LF LF (some clients use this)
      NSData *lfMarker = [@"\n\n" dataUsingEncoding:NSASCIIStringEncoding];
      headerEndRange = [_rawData rangeOfData:lfMarker options:0 range:NSMakeRange(0, [_rawData length])];
    }

    if (headerEndRange.location != NSNotFound)
    {
      _headerComplete = YES;

      // Parse the header data
      NSData *headerData = [_rawData subdataWithRange:NSMakeRange(0, headerEndRange.location + headerEndRange.length)];
      NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSASCIIStringEncoding];

      if (headerString)
      {
        [self parseHeaders:headerString];
      }

      // Extract body data if any
      NSUInteger bodyStart = headerEndRange.location + headerEndRange.length;
      if ([_rawData length] > bodyStart)
      {
        NSData *bodyData = [_rawData subdataWithRange:NSMakeRange(bodyStart, [_rawData length] - bodyStart)];
        [_body appendData:bodyData];
      }

      [_rawData setLength:0];
    }
  }
  else
  {
    // Headers are complete, append to body
    [_body appendData:data];
  }

  return YES;
}

- (void)parseHeaders:(NSString *)headerString
{
  NSArray *lines;

  // Try splitting by "\r\n" first (standard HTTP line ending)
  // Check if the string actually contains "\r\n" delimiter
  if ([headerString rangeOfString:@"\r\n"].location != NSNotFound)
  {
    // Found "\r\n" delimiter, use this split
    lines = [headerString componentsSeparatedByString:@"\r\n"];
  }
  else
  {
    // No "\r\n" found, try "\n" (some clients use just LF)
    lines = [headerString componentsSeparatedByString:@"\n"];
  }

  // componentsSeparatedByString: always returns at least one element,
  // so check if we have meaningful content (non-empty first line)
  if ([lines count] == 0 || [[lines objectAtIndex:0] length] == 0)
  {
    return;
  }

  // Parse first line (request line or status line)
  NSString *firstLine = [lines objectAtIndex:0];
  NSArray *firstLineParts = [firstLine componentsSeparatedByString:@" "];

  if (_isRequest && [firstLineParts count] >= 3)
  {
    // Request line: METHOD URL VERSION
    _method = [[firstLineParts objectAtIndex:0] copy];
    NSString *urlString = [firstLineParts objectAtIndex:1];

    // Handle both absolute URLs and relative paths
    // Try absolute URL first
    NSURL *parsedURL = [NSURL URLWithString:urlString];

    // If that fails (nil), it's likely a relative path like "/endpoint"
    // Create a URL with a base URL to handle relative paths
    if (!parsedURL)
    {
      // Use a dummy base URL to allow relative path parsing
      NSURL *baseURL = [NSURL URLWithString:@"http://localhost"];
      parsedURL = [NSURL URLWithString:urlString relativeToURL:baseURL];
    }

    _url = [parsedURL copy];
    if ([firstLineParts count] >= 3)
    {
      _version = [[firstLineParts objectAtIndex:2] copy];
    }
  }
  else if (!_isRequest && [firstLineParts count] >= 3)
  {
    // Status line: VERSION CODE DESCRIPTION
    _version = [[firstLineParts objectAtIndex:0] copy];
    _statusCode = [[firstLineParts objectAtIndex:1] integerValue];
    NSMutableArray *descParts = [NSMutableArray arrayWithArray:firstLineParts];
    [descParts removeObjectAtIndex:0];
    [descParts removeObjectAtIndex:0];
    _statusDescription = [[descParts componentsJoinedByString:@" "] copy];
  }

  // Parse header fields
  for (NSUInteger i = 1; i < [lines count]; i++)
  {
    NSString *line = [lines objectAtIndex:i];
    if ([line length] == 0)
    {
      continue;
    }

    NSRange colonRange = [line rangeOfString:@":"];
    if (colonRange.location != NSNotFound)
    {
      NSString *headerName = [[line substringToIndex:colonRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      NSString *headerValue = [[line substringFromIndex:colonRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

      if ([headerName length] > 0)
      {
        // HTTP headers are case-insensitive, but we'll store them with their original case
        // For lookup, we'll use case-insensitive comparison
        [_headers setObject:headerValue forKey:headerName];
      }
    }
  }
}

- (BOOL)isHeaderComplete
{
  return _headerComplete;
}

- (NSString *)version
{
  return _version;
}

- (NSString *)method
{
  return _method;
}

- (NSURL *)url
{
  return _url;
}

- (NSInteger)statusCode
{
  return _statusCode;
}

- (NSDictionary *)allHeaderFields
{
  return [_headers copy];
}

- (NSString *)headerField:(NSString *)headerField
{
  // Case-insensitive lookup
  for (NSString *key in [_headers allKeys])
  {
    if ([key caseInsensitiveCompare:headerField] == NSOrderedSame)
    {
      return [_headers objectForKey:key];
    }
  }
  return nil;
}

- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue
{
  if (headerField && headerFieldValue)
  {
    // Remove existing header with same name (case-insensitive)
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSString *key in [_headers allKeys])
    {
      if ([key caseInsensitiveCompare:headerField] == NSOrderedSame)
      {
        [keysToRemove addObject:key];
      }
    }
    [_headers removeObjectsForKeys:keysToRemove];

    // Add new header
    [_headers setObject:headerFieldValue forKey:headerField];
  }
}

- (NSData *)messageData
{
  NSMutableString *messageString = [NSMutableString string];

  if (_isRequest)
  {
    // Request line
    // For relative URLs, use the path component; for absolute URLs, use absoluteString
    NSString *urlString = nil;
    if (_url)
    {
      // If it's a relative URL (has a base), use the relative path
      // Otherwise use absoluteString or path
      if ([_url baseURL])
      {
        // Relative URL - use the relative portion
        urlString = [_url relativeString];
      }
      else
      {
        // Absolute URL
        urlString = [_url absoluteString];
        if (!urlString)
        {
          urlString = [_url path];
        }
      }
    }
    [messageString appendFormat:@"%@ %@ %@\r\n", _method ?: @"GET", urlString ?: @"/", _version ?: HTTPVersion1_1];
  }
  else
  {
    // Status line
    [messageString appendFormat:@"%@ %ld %@\r\n", _version ?: HTTPVersion1_1, (long)_statusCode, _statusDescription ?: @""];
  }

  // Headers
  for (NSString *key in [_headers allKeys])
  {
    NSString *value = [_headers objectForKey:key];
    [messageString appendFormat:@"%@: %@\r\n", key, value];
  }

  // Empty line to separate headers from body
  [messageString appendString:@"\r\n"];

  NSMutableData *data = [NSMutableData dataWithData:(id)[messageString dataUsingEncoding:NSASCIIStringEncoding]];

  // Append body if present
  if ([_body length] > 0)
  {
    [data appendData:_body];
  }

  return data;
}

- (NSData *)body
{
  return [_body copy];
}

- (void)setBody:(NSData *)body
{
  if (body)
  {
    _body = [body mutableCopy];
  }
  else
  {
    _body = [[NSMutableData alloc] init];
  }
}

- (void)dealloc
{
  // ARC automatically releases all instance variables, but we include this
  // for clarity and to match the pattern of the original CFNetwork implementation.
  // All Objective-C objects (_headers, _body, _rawData, _version, _method, _url, _statusDescription)
  // will be automatically released by ARC when this object is deallocated.
#if ! __has_feature(objc_arc)
  [_headers release];
  [_body release];
  [_rawData release];
  [_version release];
  [_method release];
  [_url release];
  [_statusDescription release];
  [super dealloc];
#endif
}

@end
