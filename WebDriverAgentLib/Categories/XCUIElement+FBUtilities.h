/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/FBElement.h>
#import <WebDriverAgentLib/FBXCElementSnapshot.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBUtilities)

/**
 Gets the most recent snapshot of the current element. The element will be
 automatically resolved if the snapshot is not available yet.
 Calls to this method mutate the `lastSnapshot` instance property.
 The snapshot is taken by the native API provided by XCTest.
 The maximum snapshot tree depth is set by `FBConfiguration.snapshotMaxDepth`

 Snapshot specifics:
 - Most performant
 - Memory-friedly
 - `children` property is set to `nil` if not taken from XCUIApplication
 - `value` property is cut off to max 512 bytes

 @return The recent snapshot of the element
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
 */
- (id<FBXCElementSnapshot>)fb_standardSnapshot;

/**
 Gets the most recent snapshot of the current element. The element will be
 automatically resolved if the snapshot is not available yet.
 Calls to this method mutate the `lastSnapshot` instance property.
 The maximum snapshot tree depth is set by `FBConfiguration.snapshotMaxDepth`

 Snapshot specifics:
 - Less performant in comparison to the standard one
 - `children` property is always defined
 - `value` property is not cut off

 @return The recent snapshot of the element
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
 */
- (id<FBXCElementSnapshot>)fb_customSnapshot;

/**
 Gets the most recent snapshot of the current element. The element will be
 automatically resolved if the snapshot is not available yet.
 Calls to this method mutate the `lastSnapshot` instance property.
 The maximum snapshot tree depth is set by `FBConfiguration.snapshotMaxDepth`

 Snapshot specifics:
 - Less performant in comparison to the standard one
 - The `hittable` property calculation is aligned with the native calculation logic

 @return The recent snapshot of the element
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
 */
- (id<FBXCElementSnapshot>)fb_nativeSnapshot;

/**
 Extracts the cached element snapshot from its query.
 No requests to the accessiblity framework is made.
 It is only safe to use this call right after element lookup query
 has been executed.

 @return Either the cached snapshot or nil
 */
- (nullable id<FBXCElementSnapshot>)fb_cachedSnapshot;

/**
 Filters elements by matching them to snapshots from the corresponding array

 @param snapshots Array of snapshots to be matched with
 @param onlyChildren Whether to only look for direct element children

 @return Array of filtered elements, which have matches in snapshots array
 */
- (NSArray<XCUIElement *> *)fb_filterDescendantsWithSnapshots:(NSArray<id<FBXCElementSnapshot>> *)snapshots
                                                 onlyChildren:(BOOL)onlyChildren;

/**
 Waits until element snapshot is stable to avoid "Error copying attributes -25202 error".
 This error usually happens for testmanagerd if there is an active UI animation in progress and
 causes 15-seconds delay while getting hitpoint value of element's snapshot.
*/
- (void)fb_waitUntilStable;

/**
 Waits for receiver's snapshot to become stable with the given timeout

 @param timeout The max time to wait util the snapshot is stable
*/
- (void)fb_waitUntilStableWithTimeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
