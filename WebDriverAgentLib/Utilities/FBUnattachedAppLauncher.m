//
//  FBUnattachedAppLauncher.m
//  WebDriverAgentLib
//
//  Created by Jonathan Beyrak-Lev on 09/07/2019.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import "FBUnattachedAppLauncher.h"
#import "LSApplicationWorkspace.h"

@implementation FBUnattachedAppLauncher

+ (BOOL)launchAppWithBundleId:(NSString *)bundleId {
  return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:bundleId];
}

@end
