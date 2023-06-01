/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBPickerWheel.h"

#import "FBRunLoopSpinner.h"
#import "FBXCElementSnapshot.h"
#import "FBXCodeCompatibility.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBResolve.h"

#if !TARGET_OS_TV
@implementation XCUIElement (FBPickerWheel)

static const NSTimeInterval VALUE_CHANGE_TIMEOUT = 2;

- (BOOL)fb_scrollWithOffset:(CGFloat)relativeHeightOffset error:(NSError **)error
{
  id<FBXCElementSnapshot> snapshot = self.fb_isResolvedFromCache.boolValue
    ? self.lastSnapshot
    : self.fb_takeSnapshot;
  NSString *previousValue = snapshot.value;
  XCUICoordinate *startCoord = [self coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)];
  XCUICoordinate *endCoord = [startCoord coordinateWithOffset:CGVectorMake(0.0, relativeHeightOffset * snapshot.frame.size.height)];
  // If picker value is reflected in its accessiblity id
  // then fetching of the next snapshot may fail with StaleElementReferenceError
  // because we bound elements by their accessbility ids by default.
  // Fetching stable instance of an element allows it to be bounded to the
  // unique element identifier (UID), so it could be found next time even if its
  // id is different from the initial one. See https://github.com/appium/appium/issues/17569
  XCUIElement *stableInstance = self.fb_stableInstance;
  [endCoord tap];
  return [[[[FBRunLoopSpinner new]
     timeout:VALUE_CHANGE_TIMEOUT]
    timeoutErrorMessage:[NSString stringWithFormat:@"Picker wheel value has not been changed after %@ seconds timeout", @(VALUE_CHANGE_TIMEOUT)]]
   spinUntilTrue:^BOOL{
     return ![stableInstance.value isEqualToString:previousValue];
   }
   error:error];
}

- (BOOL)fb_selectNextOptionWithOffset:(CGFloat)offset error:(NSError **)error
{
  return [self fb_scrollWithOffset:offset error:error];
}

- (BOOL)fb_selectPreviousOptionWithOffset:(CGFloat)offset error:(NSError **)error
{
  return [self fb_scrollWithOffset:-offset error:error];
}

@end
#endif
