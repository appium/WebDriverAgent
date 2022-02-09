/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import "TouchSpotView.h"

@implementation TouchSpotView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = UIColor.lightGrayColor;
  }
  return self;
}

- (void)setBounds:(CGRect)newBounds
{
  super.bounds = newBounds;
  self.layer.cornerRadius = newBounds.size.width / 2.0;
}

@end
