//
//  FBUnattachedAppLauncher.h
//  WebDriverAgentLib
//
//  Created by Jonathan Beyrak-Lev on 09/07/2019.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBUnattachedAppLauncher : NSObject

+ (BOOL)launchAppWithBundleId:(NSString *)bundleId;

@end

NS_ASSUME_NONNULL_END
