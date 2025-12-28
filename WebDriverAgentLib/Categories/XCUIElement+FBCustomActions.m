/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIElement+FBCustomActions.h"
#import "XCUIElement+FBUtilities.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "FBLogger.h"
#import "FBConfiguration.h"
#import "XCTestPrivateSymbols.h"

@interface FBXCElementSnapshotWrapper (FBCustomActionsInternal)

- (NSString *)fb_stringAttribute:(NSString *)attributeName                            
                          symbol:(NSNumber *)symbol;

@end

@implementation XCUIElement (FBCustomActions)

- (NSString *)fb_customActions
{
  @autoreleasepool {
    id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
    return [[FBXCElementSnapshotWrapper ensureWrapped:snapshot]
            fb_customActions];
  }
}

@end


@implementation FBXCElementSnapshotWrapper(FBCustomActions)

- (NSString *)fb_customActions
{
  return [self fb_stringAttribute:FB_XCAXACustomActionsAttributeName
                           symbol:FB_XCAXACustomActionsAttribute];
}

- (NSString *)fb_stringAttribute:(NSString *)attributeName
                            symbol:(NSNumber *)symbol
{
  id cached = (self.snapshot.additionalAttributes ?: @{})[symbol];
  if ([cached isKindOfClass:[NSString class]]) {
    return cached;
  }
  
  NSError *error = nil;
  id raw = [self fb_attributeValue:attributeName error:&error];
  if (raw == nil) {
    [FBLogger logFmt: @"[FBCustomActions] Cannot determine string value for %@: %@",
     attributeName, error.localizedDescription];
    return nil;
  }
  
  // Case 1: Already a string
  if ([raw isKindOfClass:[NSString class]]) {
    return [self retrieveCustomActionsFromString:raw forSymbol:symbol];
  }
  
  // Case 2: Array of custom actions
  if ([raw isKindOfClass:[NSArray class]]) {
    return [self retrieveCustomActionsFromArray:raw forSymbol:symbol];
  }
  
  // Fallback: Try to cast to string
  return [self retrieveCustomActionsByCastingToString:raw forSymbol:symbol];
}

- (NSString *)retrieveCustomActionsFromString:(NSString *)stringValue
                                    forSymbol:(NSNumber *)symbol
{
  NSMutableDictionary *updated =
  (self.additionalAttributes ?: @{}).mutableCopy;
  updated[symbol] = stringValue;
  self.snapshot.additionalAttributes = updated.copy;
  return stringValue;
}

- (NSString *)retrieveCustomActionsFromArray:(NSArray *)arrayValue
                                   forSymbol:(NSNumber *)symbol
{
  NSMutableArray *stringified = [NSMutableArray array];
  for (id action in arrayValue) {
    NSString *title = nil;
    
    if ([action isKindOfClass:[NSDictionary class]]) {
      title = ((NSDictionary *)action)[@"CustomActionName"];
    }
    
    if (!title || ![title isKindOfClass:[NSString class]]) {
      @try {
        title = [action valueForKey:@"title"];
      } @catch (__unused NSException * e) {
        title = @"<unknown>";
      }
    }
    
    [stringified addObject:title ?: @"<null>"];
    [FBLogger logFmt: @"[FBCustomActions] Custom action title: %@", title];
  }
  
  NSString *joined = [stringified componentsJoinedByString:@","];
  NSMutableDictionary *updated =
  (self.additionalAttributes ?: @{}).mutableCopy;
  updated[symbol] = joined;
  self.snapshot.additionalAttributes = updated.copy;
  return joined;
}

- (NSString *)retrieveCustomActionsByCastingToString:(id)raw
                                           forSymbol:(NSNumber *)symbol
{
  NSString *stringValue = [NSString stringWithFormat:@"%@", raw];
  NSMutableDictionary *updated =
  (self.additionalAttributes ?: @{}).mutableCopy;
  updated[symbol] = stringValue;
  self.snapshot.additionalAttributes = updated.copy;
  return stringValue;
}

@end
