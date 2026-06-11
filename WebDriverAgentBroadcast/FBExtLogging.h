/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <os/log.h>

/**
 Minimal logging for the broadcast extension. FBLogger cannot be used here because it pulls in
 FBConfiguration and, transitively, XCTest, which is forbidden in app extensions.
 View with: log stream --predicate 'subsystem == "com.facebook.WebDriverAgent.broadcast"'
 */
static inline os_log_t FBExtLog(void)
{
  static os_log_t logger;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    logger = os_log_create("com.facebook.WebDriverAgent.broadcast", "extension");
  });
  return logger;
}

#define FBExtLogInfo(...) os_log_info(FBExtLog(), __VA_ARGS__)
#define FBExtLogError(...) os_log_error(FBExtLog(), __VA_ARGS__)
