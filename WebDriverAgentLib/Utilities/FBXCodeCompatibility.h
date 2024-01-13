/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/WebDriverAgentLib.h>
#import "XCPointerEvent.h"

/**
 The version of testmanagerd process which is running on the device.

 Potentially, we can handle processes based on this version instead of iOS versions,
 iOS 10.1 -> 6
 iOS 11.0.1 -> 18
 iOS 11.4 -> 22
 iOS 12.1, 12.4 -> 26
 iOS 13.0, 13.4.1 -> 28

 tvOS 13.3 -> 28

 @return The version of testmanagerd
 */
NSInteger FBTestmanagerdVersion(void);

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElementQuery (FBCompatibility)

/* Performs short-circuit UI tree traversion in iOS 11+ to get the first element matched by the query. Equals to nil if no matching elements are found */
@property(nullable, readonly) XCUIElement *fb_firstMatch;

/*
 This is the local wrapper for bounded elements extraction.
 It uses either indexed or bounded binding based on the `boundElementsByIndex` configuration
 flag value.
 */
@property(readonly) NSArray<XCUIElement *> *fb_allMatches;

/**
 Returns single unique matching snapshot for the given query

 @param error The error instance if there was a failure while retrieveing the snapshot
 @returns The cached unqiue snapshot or nil if the element is stale
 */
- (nullable XCElementSnapshot *)fb_uniqueSnapshotWithError:(NSError **)error;

@end


@interface XCPointerEvent (FBCompatibility)

- (BOOL)fb_areKeyEventsSupported;

@end


@interface XCUIElement (FBCompatibility)

/**
 Determines whether current iOS SDK supports non modal elements inlusion into snapshots

 @return Either YES or NO
 */
+ (BOOL)fb_supportsNonModalElementsInclusion;

/**
 Retrieves element query

 @return Element query property extended with non modal elements depending on the actual configuration
 */
- (XCUIElementQuery *)fb_query;

@end

NS_ASSUME_NONNULL_END
