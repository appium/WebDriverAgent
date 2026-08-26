/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

@protocol FBXCAccessibilityElement;

NS_ASSUME_NONNULL_BEGIN

/**
 This class acts as a proxy between WDA and XCAXClient_iOS.
 Other classes are obliged to use its methods instead of directly accessing XCAXClient_iOS,
 since Apple resticted the interface of XCAXClient_iOS class since Xcode10.2
 */
@interface FBXCAXClientProxy : NSObject

+ (instancetype)sharedClient;

/**
 Bounds how long a single accessibility (AX) request issued by this process is allowed
 to wait for a reply from the AX server (the "AXTimeout" property of XCAXClient_iOS/
 XCUIAccessibilityInterface). Every AX-backed call funneled through this proxy -
 systemApplication, activeApplications, snapshotForElement:..., attributesForElement:...
 - is bounded by this single, process-wide value; there is no per-call override.

 Important: this only bounds how long the CALLING thread waits for a reply. The AX
 server itself is not told to cancel the request when this timeout elapses - the
 request keeps running/queued on the AX side regardless of whether this process gave
 up waiting on it. All AX requests from this process share one serial channel to the
 AX server, so if the target app's UI is genuinely unresponsive, lowering this value
 does not reduce the amount of queued work or make the server itself more responsive -
 it only makes each individual caller give up sooner, while requests already abandoned
 by their callers keep occupying the channel and can still delay whatever is queued
 behind them by their original, un-shortened duration.
 */
- (BOOL)setAXTimeout:(NSTimeInterval)timeout error:(NSError **)error;

/**
 The AXTimeout value currently in effect. See -setAXTimeout:error: for what it bounds.
 */
- (NSTimeInterval)axTimeout;

- (nullable id<FBXCElementSnapshot>)snapshotForElement:(id<FBXCAccessibilityElement>)element
                                            attributes:(nullable NSArray<NSString *> *)attributes
                                               inDepth:(BOOL)inDepth
                                                 error:(NSError **)error;

- (NSArray<id<FBXCAccessibilityElement>> *)activeApplications;

- (id<FBXCAccessibilityElement>)systemApplication;

- (NSDictionary *)defaultParameters;

- (void)notifyWhenNoAnimationsAreActiveForApplication:(XCUIApplication *)application
                                                reply:(void (^)(void))reply;

/**
 Wraps the private -[XCAXClient_iOS notifyWhenEventLoopIsIdleForApplication:reply:],
 used to check run loop responsiveness before a snapshot request (#1210).
 `reply` may fire more than once per call; `error` is non-nil only if monitoring
 itself could not be started.
 */
- (void)notifyWhenEventLoopIsIdleForApplication:(XCUIApplication *)application
                                           reply:(void (^)(id _Nullable result, NSError * _Nullable error))reply;

- (nullable NSDictionary *)attributesForElement:(id<FBXCAccessibilityElement>)element
                                     attributes:(NSArray *)attributes
                                          error:(NSError**)error;

- (nullable XCUIApplication *)monitoredApplicationWithProcessIdentifier:(int)pid;

/**
 Bounds how long a single XPC round trip of an XCTest automation-session request is
 allowed to take (the private `_XCTXPCRequestTimeout`/`_XCTSetXPCRequestTimeout`
 globals). This is the XCTest-level analog of -setAXTimeout:error:, but scoped wider:
 virtually every timeout-bounded automation call in the process - element matching,
 attribute/snapshot fetches, event confirmation, and the AX-backed calls above - is
 ultimately funneled through `+[XCTFuture futureWithTimeout:description:block:]`,
 which uses this value as its default wait bound. Like AXTimeout, it is a single,
 process-wide setting with no per-call override.

 `futureWithTimeout:description:block:` is a synchronous wait wrapper: it starts the
 real (asynchronous) XPC request and blocks the calling thread until either the reply
 arrives or this timeout elapses, then returns either way - but elapsing the timeout
 does NOT cancel the underlying XPC request. It keeps running to completion on the
 same serial channel regardless of whether anyone is still waiting on it.

 Practical consequence: all XPC-bounded requests from this process share one queue to
 the automation session. If the target app's main thread/run loop is genuinely stuck,
 lowering this timeout does not shrink the backlog or make the target more responsive
 - it only makes the CALLER give up sooner. A request issued right after an earlier
 one "times out" still has to wait behind that earlier request's real completion (which
 keeps consuming the channel in the background), so it can take just as long, or longer,
 to be serviced - repeatedly retrying after a timeout adds more queued work rather than
 freeing up the channel, and can never be used to reliably bound end-to-end latency
 while the target is unresponsive.
 */
- (void)setXPCRequestTimeout:(NSTimeInterval)timeout;

/**
 The XPC request timeout value currently in effect. See -setXPCRequestTimeout: for
 what it bounds.
 */
- (NSTimeInterval)xpcRequestTimeout;

@end

NS_ASSUME_NONNULL_END
