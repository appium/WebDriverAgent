/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBForceTouch.h"

#if !TARGET_OS_TV

#import "FBErrorBuilder.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"

@implementation XCUIElement (FBForceTouch)

- (BOOL)fb_forceTouchCoordinate:(NSValue *)relativeCoordinate
                       pressure:(NSNumber *)pressure
                       duration:(NSNumber *)duration
                          error:(NSError **)error
{
  if (![XCUIDevice sharedDevice].supportsPressureInteraction) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Force press is not supported on this device"]
            buildError:error];
  }

  if (nil == relativeCoordinate) {
    if (nil == pressure || nil == duration) {
      [self forcePress];
    } else {
      [self pressWithPressure:[pressure doubleValue] duration:[duration doubleValue]];
    }
  } else {
    CGSize size = self.frame.size;
    CGVector offset = CGVectorMake(size.width > 0 ? relativeCoordinate.CGPointValue.x / size.width : 0,
                                   size.height > 0 ? relativeCoordinate.CGPointValue.y / size.height : 0);
    XCUICoordinate *hitPoint = [self coordinateWithNormalizedOffset:offset];
    if (nil == pressure || nil == duration) {
      [hitPoint forcePress];
    } else {
      [hitPoint pressWithPressure:[pressure doubleValue] duration:[duration doubleValue]];
    }
  }
  return YES;
}

@end

#endif
