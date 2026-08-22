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
  // A self dispatch_sync would trip the OS watchdog and get the process
  // killed outright. Sleeping instead simulates an app that stops answering
  // accessibility requests while staying alive, per #1210.
  [NSThread sleepForTimeInterval:20.0];
}

- (IBAction)didTapButton:(UIButton *)button
{
  button.selected = !button.selected;
}

- (IBAction)goToDeepHierarchy:(id)sender
{
  // Plain UIViews with fixed frames only - no Auto Layout constraints and no
  // specialized subclasses (e.g. UITextView) that carry their own layout/text
  // engines, which can make a deep nested chain pathologically expensive to
  // lay out. This page exists purely as a fixture for exercising element
  // lookups (e.g. class chain locators) against a deep accessibility tree.
  UIViewController *deepHierarchyViewController = [UIViewController new];
  deepHierarchyViewController.view.backgroundColor = UIColor.whiteColor;
  deepHierarchyViewController.view.accessibilityIdentifier = @"DeepHierarchyPage";

  NSInteger depth = 70;
  // A plain UILabel sibling, not part of the nested chain below, so the
  // fixture stays recognizable to a human glancing at the simulator instead
  // of showing a blank white screen.
  UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, CGRectGetWidth(UIScreen.mainScreen.bounds) - 40, 60)];
  titleLabel.text = [NSString stringWithFormat:@"Deep Hierarchy\n%ld nested elements", (long)depth];
  titleLabel.numberOfLines = 2;
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.font = [UIFont systemFontOfSize:20];
  [deepHierarchyViewController.view addSubview:titleLabel];

  UIView *parent = deepHierarchyViewController.view;
  for (NSInteger i = 0; i < depth; i++) {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    view.accessibilityIdentifier = [NSString stringWithFormat:@"view_%ld", (long)i];
    view.accessibilityLabel = [NSString stringWithFormat:@"View %ld", (long)i];
    [parent addSubview:view];
    parent = view;
  }

  [self.navigationController pushViewController:deepHierarchyViewController animated:NO];
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
