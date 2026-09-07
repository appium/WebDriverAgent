/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBScrollViewController.h"

#import "FBTableDataSource.h"

static const CGFloat FBSubviewHeight = 40.0;

@interface FBScrollViewController ()
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet FBTableDataSource *dataSource;
@property (nonatomic, copy) NSArray<UILabel *> *rowLabels;
@end

@implementation FBScrollViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupLabelViews];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  CGFloat width = CGRectGetWidth(self.scrollView.bounds);
  [self.rowLabels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger index, BOOL *stop) {
    label.frame = CGRectMake(0, index * FBSubviewHeight, width, FBSubviewHeight);
  }];
  self.scrollView.contentSize = CGSizeMake(width, self.rowLabels.count * FBSubviewHeight);
}

- (void)setupLabelViews
{
  NSUInteger count = self.dataSource.count;
  NSMutableArray<UILabel *> *labels = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0 ; i < count ; i++) {
    UILabel *label = [UILabel new];
    label.text = [self.dataSource textForElementAtIndex:i];
    label.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:label];
    [labels addObject:label];
  }
  self.rowLabels = labels;
}

@end
