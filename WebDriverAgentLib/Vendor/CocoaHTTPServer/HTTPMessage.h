/**
 * The HTTPMessage class is a simple Objective-C wrapper for HTTP message parsing.
 * Migrated from CFHTTPMessage to use Foundation and Network framework.
 **/

#import <Foundation/Foundation.h>

#define HTTPVersion1_0  @"HTTP/1.0"
#define HTTPVersion1_1  @"HTTP/1.1"


@interface HTTPMessage : NSObject
{
  NSMutableDictionary *_headers;
  NSMutableData *_body;
  NSString *_version;
  NSString *_method;
  NSURL *_url;
  NSInteger _statusCode;
  NSString *_statusDescription;
  BOOL _isRequest;
  BOOL _headerComplete;
  NSMutableData *_rawData;
}

- (id)initEmptyRequest;

- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version;

- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version;

- (BOOL)appendData:(NSData *)data;

- (BOOL)isHeaderComplete;

- (NSString *)version;

- (NSString *)method;
- (NSURL *)url;

- (NSInteger)statusCode;

- (NSDictionary *)allHeaderFields;
- (NSString *)headerField:(NSString *)headerField;

- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue;

- (NSData *)messageData;

- (NSData *)body;
- (void)setBody:(NSData *)body;

@end
