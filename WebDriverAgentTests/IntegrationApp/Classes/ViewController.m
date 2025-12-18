/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *orentationLabel;
@property (weak, nonatomic) IBOutlet UIButton *button;
@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  UIAccessibilityCustomAction *action1 =
  [[UIAccessibilityCustomAction alloc] initWithName:@"Custom Action 1"
                                             target:self
                                           selector:@selector(handleCustomAction:)];
  UIAccessibilityCustomAction *action2 =
  [[UIAccessibilityCustomAction alloc] initWithName:@"Custom Action 2"
                                             target:self
                                           selector:@selector(handleCustomAction:)];
  self.button.accessibilityCustomActions = @[action1, action2];
}

- (BOOL)handleCustomAction:(UIAccessibilityCustomAction *)action
{
  // Custom action handler - just return YES to indicate success
  return YES;
}

- (IBAction)deadlockApp:(id)sender
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    // This will never execute
  });
}

- (IBAction)didTapButton:(UIButton *)button
{
  button.selected = !button.selected;
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self updateOrentationLabel];
}

#if !TARGET_OS_TV
- (void)updateOrentationLabel
{
  NSString *orientation = nil;
  switch (UIDevice.currentDevice.orientation) {
    case UIInterfaceOrientationPortrait:
      orientation = @"Portrait";
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      orientation = @"PortraitUpsideDown";
      break;
    case UIInterfaceOrientationLandscapeLeft:
      orientation = @"LandscapeLeft";
      break;
    case UIInterfaceOrientationLandscapeRight:
      orientation = @"LandscapeRight";
      break;
    case UIDeviceOrientationFaceUp:
      orientation = @"FaceUp";
      break;
    case UIDeviceOrientationFaceDown:
      orientation = @"FaceDown";
      break;
    case UIInterfaceOrientationUnknown:
      orientation = @"Unknown";
      break;
  }
  self.orentationLabel.text = orientation;
}
#endif

@end
