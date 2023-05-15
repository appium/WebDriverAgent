/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBTap.h"


#if !TARGET_OS_TV
@implementation XCUIElement (FBTap)

- (BOOL)fb_tapWithError:(NSError **)error
{
  [self tap];
  return YES;
}

- (BOOL)fb_tapCoordinate:(CGPoint)relativeCoordinate error:(NSError **)error
{
  XCUICoordinate *startCoordinate = [self coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
  CGVector offset = CGVectorMake(relativeCoordinate.x, relativeCoordinate.y);
  XCUICoordinate *dstCoordinate = [startCoordinate coordinateWithOffset:offset];
  [dstCoordinate tap];
  return YES;
}

@end
#endif
