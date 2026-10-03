/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScreen.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXCodeCompatibility.h"
#import "XCUIDevice.h"
#import "XCUIScreen.h"

@implementation FBScreen

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)screensWithError:(NSError **)error
{
  NSArray<XCUIScreen *> *screens = [XCUIDevice.sharedDevice screensOrError:error];
  if (nil == screens) {
    return nil;
  }

  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray arrayWithCapacity:screens.count];
  for (XCUIScreen *screen in screens) {
    CGRect bounds = screen.bounds;
    [result addObject:@{
      @"displayId": @(screen.displayID),
      @"isMain": @(screen.isMainScreen),
      @"scale": @(screen.scale),
      @"bounds": @{
        @"x": @(bounds.origin.x),
        @"y": @(bounds.origin.y),
        @"width": @(bounds.size.width),
        @"height": @(bounds.size.height),
      },
      @"traits": @(screen.traits),
    }];
  }
  return result.copy;
}

// Kept separate from sharedDevice so legacy lookup behavior can be tested.
+ (nullable XCUIScreen *)screenWithDisplayID:(long long)displayID
                                    device:(XCUIDevice *)device
                                     error:(NSError **)error
{
  BOOL hasNativeLookup = [device respondsToSelector:@selector(screenWithDisplayID:orError:)];
  BOOL needsEnumeratedLookup = !hasNativeLookup;
  NSError *lookupError = nil;
  if (hasNativeLookup) {
    XCUIScreen *screen = [device screenWithDisplayID:displayID orError:&lookupError];
    if (nil != screen && !CGRectIsEmpty(screen.bounds)) {
      return screen;
    }
    // XCTest may return a zero-sized placeholder for an inactive wireless
    // display which screensOrError: omits. Confirm its availability by listing.
    needsEnumeratedLookup = nil != screen;
  }
  // Enumerate only for legacy/placeholder lookups or to enrich a lookup error.
  NSError *enumerationError = nil;
  NSArray<XCUIScreen *> *screens = [device screensOrError:&enumerationError];
  if (nil == screens) {
    if (NULL != error) {
      *error = lookupError ?: enumerationError;
    }
    return nil;
  }
  NSMutableArray<NSNumber *> *availableIDs = [NSMutableArray arrayWithCapacity:screens.count];
  for (XCUIScreen *screen in screens) {
    if (needsEnumeratedLookup && screen.displayID == displayID) {
      return screen;
    }
    [availableIDs addObject:@(screen.displayID)];
  }
  FBErrorBuilder *builder = [FBErrorBuilder.builder withDescriptionFormat:
    @"No display with id %lld is available. Available display ids: [%@]",
    displayID, [availableIDs componentsJoinedByString:@", "]];
  if (nil != lookupError) {
    [builder withInnerError:lookupError];
  }
  [builder buildError:error];
  return nil;
}

+ (nullable XCUIScreen *)screenWithDisplayID:(long long)displayID error:(NSError **)error
{
  return [self screenWithDisplayID:displayID device:XCUIDevice.sharedDevice error:error];
}

+ (nullable XCUIScreen *)currentScreenWithError:(NSError **)error
{
  NSNumber *displayID = FBConfiguration.sharedInstance.currentDisplayId;
  if (nil == displayID) {
    return XCUIScreen.mainScreen;
  }
  return [self screenWithDisplayID:displayID.longLongValue error:error];
}

+ (long long)displayID
{
  return XCUIScreen.mainScreen.displayID;
}

+ (double)scale
{
  return [XCUIScreen.mainScreen scale];
}

@end
