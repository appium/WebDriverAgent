/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Hosts an (effectively invisible) RPSystemBroadcastPickerView inside the runner app and
 triggers its button programmatically, which makes the system present the broadcast
 confirmation sheet. Main thread only.
 */
@interface FBBroadcastPickerHost : NSObject

/**
 Creates the hosting window if needed and taps the picker's internal button.

 @param preferredExtension The bundle identifier of the broadcast upload extension to preselect
 @param error Set when the picker cannot be hosted or its button cannot be found
 @return NO in case of a failure
 */
+ (BOOL)triggerPickerWithPreferredExtension:(NSString *)preferredExtension
                                      error:(NSError **)error;

/** Hides and releases the hosting window. */
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
