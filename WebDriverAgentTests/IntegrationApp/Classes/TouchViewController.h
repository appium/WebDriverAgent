/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree.
*/

#import <UIKit/UIKit.h>
#import "TouchableView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchViewController : UIViewController

@property (weak, nonatomic) IBOutlet TouchableView *touchable;
@property (weak, nonatomic) IBOutlet UILabel *numberOfTapsLabel;
@property (weak, nonatomic) IBOutlet UILabel *numberOfTouchesLabel;


@end

NS_ASSUME_NONNULL_END
