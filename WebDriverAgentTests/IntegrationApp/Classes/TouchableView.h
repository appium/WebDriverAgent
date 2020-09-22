/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import <UIKit/UIKit.h>
#import "TouchSpotView.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TouchableViewDelegate <NSObject>

- (void)shouldHandleTouchesNumber:(int)touchesCount;
- (void)shouldHandleTapsNumber:(int)numberOfTaps;

@end

@interface TouchableView : UIView

@property (nonatomic) NSMutableDictionary<NSNumber*, TouchSpotView*> *touchViews;
@property (nonatomic) int numberOFTaps;
@property (nonatomic) id delegate;

@end

NS_ASSUME_NONNULL_END
