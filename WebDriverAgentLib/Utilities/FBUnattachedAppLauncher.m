/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBUnattachedAppLauncher.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import "LSApplicationWorkspace.h"

@implementation FBUnattachedAppLauncher

+ (BOOL)launchAppWithBundleId:(NSString *)bundleId {
  return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:bundleId];
}

@end
