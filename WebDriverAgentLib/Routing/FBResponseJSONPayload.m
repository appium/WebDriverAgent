/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBResponseJSONPayload.h"
#import "FBLogger.h"
#import "RouteResponse.h"

@interface FBResponseJSONPayload ()

@property (nonatomic, copy, readonly) NSDictionary *dictionary;
@property (nonatomic, readonly) HTTPStatusCode httpStatusCode;

@end

@implementation FBResponseJSONPayload


/*
 * Convenience method to do the check and validation in one.
 */
+ (NSString*)makeValidUTF8:(NSString*)stringToCheck
{
  if (![FBResponseJSONPayload isValidUTF8 :stringToCheck])
  {
    return [FBResponseJSONPayload removeInvalidCharsFromString:stringToCheck];
  }
  return stringToCheck;
}

/*
 * Returns true if the string can be converted to UTF8
 */
+ (int)isValidUTF8:(NSString*)stringToCheck
{
  return ([stringToCheck UTF8String] != nil);
}

/*
 * Removes invalid UTF8 chars from the NSString
 * This method is slow, so only run it on strings that fail the isValidUTF8 check.
 */
+ (NSString*)removeInvalidCharsFromString:(NSString*)stringToCheck
{
  NSMutableString* fixedUp = [NSMutableString stringWithString:@""];
  for (NSUInteger i = 0; i < [stringToCheck length]; i++)
  {
    @autoreleasepool
    {
      unichar character = [stringToCheck characterAtIndex:i];
      NSString* charString = [[NSString alloc] initWithCharacters:&character length:1];
      if ([charString UTF8String] == nil) {
        [FBLogger logFmt:@"Invalid UTF-8 sequence encountered at position %lu. Code: %hu (%X). Replacing with \ufffd", (unsigned long) i, character, character];
        [fixedUp appendString:@"\ufffd"];
      } else {
        [fixedUp appendString:charString];
      }
    }
  }
  [FBLogger logFmt:@"Given JSONPayload was NOT valid utf-8. Orig length %lu, fixed length %lu", (unsigned long)[stringToCheck length], (unsigned long)[fixedUp length]];
  return fixedUp;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
                    httpStatusCode:(HTTPStatusCode)httpStatusCode
{
  NSParameterAssert(dictionary);
  if (!dictionary) {
    return nil;
  }
  NSMutableDictionary* newDictionary = [NSMutableDictionary dictionary];
  for (NSString* key in dictionary){
    if ([[dictionary objectForKey:key] isKindOfClass:[NSString class]]) {
      [newDictionary setObject:[FBResponseJSONPayload makeValidUTF8:[dictionary objectForKey:key]] forKey:key];
    } else {
      [newDictionary setObject:[dictionary objectForKey:key] forKey:key];
    }
  }
  self = [super init];
  if (self) {
    _dictionary = newDictionary;
    _httpStatusCode = httpStatusCode;
  }
  return self;
}

- (void)dispatchWithResponse:(RouteResponse *)response
{
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.dictionary
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
  NSCAssert(jsonData, @"Valid JSON must be responded, error of %@", error);
  [response setHeader:@"Content-Type" value:@"application/json;charset=UTF-8"];
  [response setStatusCode:self.httpStatusCode];
  [response respondWithData:jsonData];
}

@end
