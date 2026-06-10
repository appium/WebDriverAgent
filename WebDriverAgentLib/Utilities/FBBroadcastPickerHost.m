/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBroadcastPickerHost.h"

#import <UIKit/UIKit.h>
#if !TARGET_OS_TV
#import <ReplayKit/ReplayKit.h>
#endif

#import "FBLogger.h"

static NSString *const FBBroadcastPickerHostErrorDomain = @"com.facebook.WebDriverAgent.FBBroadcastPickerHost";

#if !TARGET_OS_TV
static UIWindow *pickerWindow = nil;
#endif

@implementation FBBroadcastPickerHost

#if TARGET_OS_TV

+ (BOOL)triggerPickerWithPreferredExtension:(NSString *)preferredExtension
                                      error:(NSError **)error
{
  if (error) {
    *error = [NSError errorWithDomain:FBBroadcastPickerHostErrorDomain
                                 code:1
                             userInfo:@{NSLocalizedDescriptionKey: @"The ReplayKit broadcast picker is not available on tvOS"}];
  }
  return NO;
}

+ (void)dismiss
{
}

#else

+ (BOOL)triggerPickerWithPreferredExtension:(NSString *)preferredExtension
                                      error:(NSError **)error
{
  NSAssert(NSThread.isMainThread, @"The broadcast picker must be triggered on the main thread");

  if (nil == pickerWindow) {
    // The picker view must live in a visible window for the system sheet to present, but the
    // window can be tiny and nearly transparent so it never interferes with the runner's UI.
    UIWindowScene *foregroundScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if ([scene isKindOfClass:UIWindowScene.class]
          && scene.activationState == UISceneActivationStateForegroundActive) {
        foregroundScene = (UIWindowScene *)scene;
        break;
      }
    }
    UIWindow *window = nil == foregroundScene
      ? [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 2, 2)]
      : [[UIWindow alloc] initWithWindowScene:foregroundScene];
    window.frame = CGRectMake(0, 0, 2, 2);
    window.windowLevel = UIWindowLevelNormal;
    window.alpha = 0.02;
    window.rootViewController = [[UIViewController alloc] init];

    RPSystemBroadcastPickerView *pickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
    pickerView.preferredExtension = preferredExtension;
    pickerView.showsMicrophoneButton = NO;
    [window.rootViewController.view addSubview:pickerView];

    pickerWindow = window;
  }
  [pickerWindow makeKeyAndVisible];

  RPSystemBroadcastPickerView *pickerView = nil;
  for (UIView *subview in pickerWindow.rootViewController.view.subviews) {
    if ([subview isKindOfClass:RPSystemBroadcastPickerView.class]) {
      pickerView = (RPSystemBroadcastPickerView *)subview;
      break;
    }
  }
  pickerView.preferredExtension = preferredExtension;

  UIButton *button = [self findButtonInView:pickerView];
  if (nil == button) {
    if (error) {
      *error = [NSError errorWithDomain:FBBroadcastPickerHostErrorDomain
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey: @"Cannot locate the button inside RPSystemBroadcastPickerView. The system view layout may have changed in this iOS version"}];
    }
    return NO;
  }
  [FBLogger log:@"Triggering the system broadcast picker"];
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];
  return YES;
}

+ (nullable UIButton *)findButtonInView:(nullable UIView *)view
{
  if (nil == view) {
    return nil;
  }
  if ([view isKindOfClass:UIButton.class]) {
    return (UIButton *)view;
  }
  for (UIView *subview in view.subviews) {
    UIButton *button = [self findButtonInView:subview];
    if (nil != button) {
      return button;
    }
  }
  return nil;
}

+ (void)dismiss
{
  if (nil == pickerWindow) {
    return;
  }
  pickerWindow.hidden = YES;
  pickerWindow = nil;
}

#endif

@end
