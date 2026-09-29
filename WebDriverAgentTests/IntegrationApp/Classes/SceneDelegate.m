/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "SceneDelegate.h"

@implementation SceneDelegate

- (void)showIdentifierLookupFixture
{
  UIViewController *controller = [UIViewController new];
  controller.view.backgroundColor = UIColor.whiteColor;
  controller.view.accessibilityIdentifier = @"IdentifierLookupFixture";
  NSArray *identifiers = @[@"something", @"different", @"", NSNull.null, @"something", @"", NSNull.null, @"quote'\"é", NSNull.null];
  NSArray<NSString *> *labels = @[@"other label", @"something", @"something", @"something", @"something", @"", @"", @"quoted", @"日本語"];
  NSMutableArray<UILabel *> *labelViews = [NSMutableArray array];
  for (NSUInteger i = 0; i < identifiers.count; i++) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 90 + i * 40, 300, 35)];
    label.text = [NSString stringWithFormat:@"Fixture %lu", (unsigned long)i];
    label.accessibilityIdentifier = identifiers[i] == NSNull.null ? nil : identifiers[i];
    label.accessibilityLabel = labels[i];
    label.isAccessibilityElement = YES;
    [labelViews addObject:label];
    [controller.view addSubview:label];
  }
  UIButton *mutate = [UIButton buttonWithType:UIButtonTypeSystem];
  mutate.frame = CGRectMake(20, 470, 220, 40);
  [mutate setTitle:@"Change identifier" forState:UIControlStateNormal];
  mutate.accessibilityIdentifier = @"mutateIdentifier";
  [mutate addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
    labelViews[0].accessibilityIdentifier = @"changed";
  }] forControlEvents:UIControlEventTouchUpInside];
  [controller.view addSubview:mutate];
  self.window.rootViewController = controller;
  [self.window makeKeyAndVisible];
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
  if ([NSProcessInfo.processInfo.arguments containsObject:@"--identifier-lookup-test"]) {
    [self showIdentifierLookupFixture];
    return;
  }
  // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
  // If using a storyboard, the `window` property will automatically be set and attached to the scene.
  // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession:` instead).
}

- (void)sceneDidDisconnect:(UIScene *)scene {
  // Called as the scene is being released by the system.
  // This occurs shortly after the scene enters the background, or when its session is discarded.
  // Release any resources associated with this scene that can be re-created the next time the scene connects.
  // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
  // Called when the scene has moved from an inactive state to an active state.
  // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}

- (void)sceneWillResignActive:(UIScene *)scene {
  // Called when the scene will move from an active state to an inactive state.
  // This may occur due to temporary interruptions (ex. an incoming phone call).
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
  // Called as the scene transitions from the background to the foreground.
  // Use this method to undo the changes made on entering the background.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
  // Called as the scene transitions from the foreground to the background.
  // Use this method to save data, release shared resources, and store enough scene-specific state information
  // to restore the scene back to its current state.
}

@end

