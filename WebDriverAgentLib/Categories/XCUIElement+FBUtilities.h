/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/XCElementSnapshot.h>
#import <WebDriverAgentLib/FBElement.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElement (FBUtilities)

/**
 Gets the most recent snapshot of the current element. The element will be
 automatically resolved if the snapshot is not available yet.
 Calls to this method mutate the `lastSnapshot` instance property..
 Calls to this method reset the `fb_isResolvedFromCache` property value to `NO`.

 @return The recent snapshot of the element
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
 */
- (XCElementSnapshot *)fb_takeSnapshot;

/**
 Extracts the cached element snapshot from its query.
 No requests to the accessiblity framework is made.
 It is only safe to use this call right after element lookup query
 has been executed.

 @return Either the cached snapshot or nil
 */
- (nullable XCElementSnapshot *)fb_cachedSnapshot;

/**
 Gets the most recent snapshot of the current element and already resolves the accessibility attributes
 needed for creating the page source of this element. No additional calls to the accessibility layer
 are required.
 Calls to this method mutate the `lastSnapshot` instance property.
 Calls to this method reset the `fb_isResolvedFromCache` property value to `NO`.

 @param maxDepth The maximum depth of the snapshot. nil value means to use the default depth.
 with custom attributes cannot be resolved
 
 @return The recent snapshot of the element with all attributes resolved or a snapshot with default
 attributes resolved if there was a failure while resolving additional attributes
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
 */
- (nullable XCElementSnapshot *)fb_snapshotWithAllAttributesAndMaxDepth:(nullable NSNumber *)maxDepth;

/**
 Gets the most recent snapshot of the current element with given attributes resolved.
 No additional calls to the accessibility layer are required.
 Calls to this method mutate the `lastSnapshot` instance property.
 Calls to this method reset the `fb_isResolvedFromCache` property value to `NO`.

 @param attributeNames The list of attribute names to resolve. Must be one of
 FB_...Name values exported by XCTestPrivateSymbols.h module.
 `nil` value means that only the default attributes must be extracted
 @param maxDepth The maximum depth of the snapshot. nil value means to use the default depth.

 @return The recent snapshot of the element with the given attributes resolved or a snapshot with default
 attributes resolved if there was a failure while resolving additional attributes
 @throws FBStaleElementException if the element is not present in DOM and thus no snapshot could be made
*/
- (nullable XCElementSnapshot *)fb_snapshotWithAttributes:(nullable NSArray<NSString *> *)attributeNames
                                                 maxDepth:(nullable NSNumber *)maxDepth;

/**
 Filters elements by matching them to snapshots from the corresponding array

 @param snapshots Array of snapshots to be matched with
 @param selfUID Optionally the unique identifier of the current element.
 Providing it as an argument improves the performance of the method.
 @param onlyChildren Whether to only look for direct element children

 @return Array of filtered elements, which have matches in snapshots array
 */
- (NSArray<XCUIElement *> *)fb_filterDescendantsWithSnapshots:(NSArray<XCElementSnapshot *> *)snapshots
                                                      selfUID:(nullable NSString *)selfUID
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

/**
 Returns screenshot of the particular element
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return Element screenshot as PNG-encoded data or nil in case of failure
 */
- (nullable NSData *)fb_screenshotWithError:(NSError*__autoreleasing*)error;

@end

NS_ASSUME_NONNULL_END
