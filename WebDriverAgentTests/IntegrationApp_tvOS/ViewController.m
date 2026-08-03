/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ViewController.h"

static NSInteger const FBGridSize = 3;
static CGFloat const FBCellSide = 200;
static CGFloat const FBCellSpacing = 60;

@interface ViewController ()
@property (nonatomic, strong) UILabel *lastSelectedLabel;
@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.whiteColor;

  UIStackView *rows = [UIStackView new];
  rows.axis = UILayoutConstraintAxisVertical;
  rows.spacing = FBCellSpacing;
  rows.alignment = UIStackViewAlignmentCenter;
  rows.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:rows];

  for (NSInteger row = 0; row < FBGridSize; row++) {
    UIStackView *columns = [UIStackView new];
    columns.axis = UILayoutConstraintAxisHorizontal;
    columns.spacing = FBCellSpacing;
    for (NSInteger column = 0; column < FBGridSize; column++) {
      UIButton *cell = [self newCellWithIdentifier:[NSString stringWithFormat:@"cell_%ld_%ld", (long)row, (long)column]];
      [columns addArrangedSubview:cell];
    }
    [rows addArrangedSubview:columns];
  }

  UIButton *disabledButton = [self newCellWithIdentifier:@"disabledButton"];
  disabledButton.enabled = NO;
  [rows addArrangedSubview:disabledButton];

  self.lastSelectedLabel = [UILabel new];
  self.lastSelectedLabel.accessibilityIdentifier = @"lastSelectedLabel";
  self.lastSelectedLabel.text = @"none";
  self.lastSelectedLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.lastSelectedLabel];

  [NSLayoutConstraint activateConstraints:@[
    [rows.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [rows.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    [self.lastSelectedLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [self.lastSelectedLabel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-FBCellSpacing],
  ]];
}

- (UIButton *)newCellWithIdentifier:(NSString *)identifier
{
  UIButton *cell = [UIButton buttonWithType:UIButtonTypeSystem];
  cell.accessibilityIdentifier = identifier;
  [cell setTitle:identifier forState:UIControlStateNormal];
  cell.translatesAutoresizingMaskIntoConstraints = NO;
  [cell.widthAnchor constraintEqualToConstant:FBCellSide].active = YES;
  [cell.heightAnchor constraintEqualToConstant:FBCellSide].active = YES;
  [cell addTarget:self action:@selector(didSelectCell:) forControlEvents:UIControlEventPrimaryActionTriggered];
  return cell;
}

- (void)didSelectCell:(UIButton *)cell
{
  self.lastSelectedLabel.text = cell.accessibilityIdentifier;
}

@end
