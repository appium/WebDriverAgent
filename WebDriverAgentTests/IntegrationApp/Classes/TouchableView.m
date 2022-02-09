/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import "TouchableView.h"

@implementation TouchableView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.multipleTouchEnabled = YES;
    self.numberOFTaps = 0;
    self.touchViews = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder:coder];
  if (self) {
    self.multipleTouchEnabled = YES;
    self.numberOFTaps = 0;
    self.touchViews = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  self.numberOFTaps += 1;
  [self.delegate shouldHandleTouchesNumber:(int)touches.count];
  for (UITouch *touch in touches)
  {
    [self createViewForTouch:touch];
  }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  for (UITouch *touch in touches)
  {
    TouchSpotView *view = [self viewForTouch:touch];
    CGPoint newLocation = [touch locationInView:self];
    view.center = newLocation;
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  for (UITouch *touch in touches)
  {
    [self removeViewForTouch:touch];
  }
  [self.delegate shouldHandleTapsNumber:self.numberOFTaps];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  for (UITouch *touch in touches)
  {
    [self removeViewForTouch:touch];
  }
}

- (void)createViewForTouch:(UITouch *)touch
{
  if (touch)
  {
    TouchSpotView *newView = [[TouchSpotView alloc] init];
    newView.bounds = CGRectMake(0, 0, 1, 1);
    newView.center = [touch locationInView:self];
    [self addSubview:newView];
    [UIView animateWithDuration:0.2 animations:^{
      newView.bounds = CGRectMake(0, 0, 100, 100);
    }];
    
    self.touchViews[[self touchHash:touch]] = newView;
  }
}

- (TouchSpotView *)viewForTouch:(UITouch *)touch
{
  return self.touchViews[[self touchHash:touch]];
}

- (void)removeViewForTouch:(UITouch *)touch
{
  NSNumber *touchHash = [self touchHash:touch];
  UIView *view = self.touchViews[touchHash];
  if (view)
  {
    [view removeFromSuperview];
    [self.touchViews removeObjectForKey:touchHash];
  }
}

- (NSNumber *)touchHash:(UITouch *)touch
{
  return [NSNumber numberWithUnsignedInteger:touch.hash];
}
@end
