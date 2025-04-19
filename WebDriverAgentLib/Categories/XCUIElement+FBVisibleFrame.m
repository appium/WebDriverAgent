/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBVisibleFrame.h"
#import "FBElementUtils.h"
#import "FBXCodeCompatibility.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBUtilities.h"
#import "XCTestPrivateSymbols.h"

@implementation XCUIElement (FBVisibleFrame)

- (CGRect)fb_visibleFrame
{
  id<FBXCElementSnapshot> snapshot = [self fb_standardSnapshot];
  return [FBXCElementSnapshotWrapper ensureWrapped:snapshot].fb_visibleFrame;
}

@end

@implementation FBXCElementSnapshotWrapper (FBVisibleFrame)

- (CGRect)fb_visibleFrame
{
  CGRect thisVisibleFrame = [self visibleFrame];
  if (!CGRectIsEmpty(thisVisibleFrame)) {
    return thisVisibleFrame;
  }

  NSDictionary *visibleFrameDict = [self fb_attributeValue:FB_XCAXAVisibleFrameAttributeName
                                                     error:nil];
  if (nil == visibleFrameDict) {
    return thisVisibleFrame;
  }

  id x = [visibleFrameDict objectForKey:@"X"];
  id y = [visibleFrameDict objectForKey:@"Y"];
  id height = [visibleFrameDict objectForKey:@"Height"];
  id width = [visibleFrameDict objectForKey:@"Width"];
  if (x != nil && y != nil && height != nil && width != nil) {
    return CGRectMake([x doubleValue], [y doubleValue], [width doubleValue], [height doubleValue]);
  }

  return thisVisibleFrame;
}

@end
