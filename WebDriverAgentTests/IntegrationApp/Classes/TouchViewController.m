/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import "TouchViewController.h"

@implementation TouchViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.touchable.delegate = self;
  self.numberOfTouchesLabel.text = @"0";
  self.numberOfTapsLabel.text = @"0";
}

- (void)shouldHandleTapsNumber:(int)numberOfTaps {
  self.numberOfTapsLabel.text = [NSString stringWithFormat:@"%d", numberOfTaps];
}

- (void)shouldHandleTouchesNumber:(int)touchesCount {
  self.numberOfTouchesLabel.text = [NSString stringWithFormat:@"%d", touchesCount];
}

@end
