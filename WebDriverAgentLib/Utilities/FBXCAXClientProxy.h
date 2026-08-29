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
 Runs `block` synchronously with AXTimeout (the "AXTimeout" property of
 XCAXClient_iOS/XCUIAccessibilityInterface, backed by the private `_XCTAXIPCTimeout`
 global) temporarily set to `timeout`, restoring the previous value once `block`
 returns (even if it throws). Bounds how long a single accessibility (AX) request
 issued by this process is allowed to wait for a reply from the AX server. Every
 AX-backed call funneled through this proxy - systemApplication, activeApplications,
 snapshotForElement:..., attributesForElement:... - is an in-process call into
 XCAXClient_iOS and is bounded by this single, process-wide value; there is no
 per-call override. Defaults to 60 seconds.

 These XCAXClient_iOS calls are themselves wrapped in
 `+[XCTFuture futureWithTimeout:description:block:]`, but that wrapper's own timeout
 is `_XCTAXClientWrapperTimeout()` - AXTimeout plus a fixed 5-second margin, not
 +withXPCRequestTimeout:do:'s `_XCTXPCRequestTimeout`. That margin exists so the AX
 layer's own timeout has a chance to fire and produce a clean error before XCTFuture's
 wrapper would cut if off anyway; it is not independently tunable. AXTimeout is
 therefore the only knob that matters for every call this proxy wraps.

 Important: this only bounds how long the CALLING thread waits for a reply. The AX
 server itself is not told to cancel the request when this timeout elapses - the
 request keeps running/queued on the AX side regardless of whether this process gave
 up waiting on it. All AX requests from this process share one serial channel to the
 AX server, so if the target app's UI is genuinely unresponsive, lowering this value
 does not reduce the amount of queued work or make the server itself more responsive -
 it only makes each individual caller give up sooner, while requests already abandoned
 by their callers keep occupying the channel and can still delay whatever is queued
 behind them by their original, un-shortened duration.

 The whole scope is serialized behind a dedicated lock, so overlapping calls from
 different threads nest/queue instead of racing to restore the global.

 If installing `timeout` fails, `block` is not run, this returns NO, and `error` (if
 given) is populated with the underlying failure. A failure while restoring the
 previous value is logged and reported via `error` independently of the return value,
 which always reflects `block`'s completion, sampled immediately after it returns and
 before the restore attempt.
 */
- (BOOL)withAXTimeout:(NSTimeInterval)timeout do:(void (^)(void))block error:(NSError **)error;

/**
 Runs `block` synchronously with the XCTest automation-session XPC request timeout
 (the private `_XCTXPCRequestTimeout`/`_XCTSetXPCRequestTimeout` globals) temporarily
 set to `timeout`, restoring the previous value once `block` returns (even if it
 throws). Defaults to 30 seconds.

 This does NOT bound anything else in this proxy - despite the similar shape, it is
 not the XCTest-level analog of -withAXTimeout:do: for the calls above. AXTimeout and
 the XPC request timeout gate two structurally different, non-nested call paths:
 XCAXClient_iOS (what this proxy wraps) makes its AX-server round trips in-process,
 bounded solely by AXTimeout (see -withAXTimeout:do:); XCTRunnerAutomationSession -
 a separate class WDA does not go through here - makes its calls over a real
 NSXPCConnection (`remoteObjectProxyWithErrorHandler:`) to another process, bounded by
 this timeout instead. `-[XCTRunnerAutomationSession matchesForQuery:error:]` (the
 primitive behind XCUIElementQuery/most element-finding lookups) and that class's own,
 identically-named `attributesForElement:attributes:error:` are the calls this timeout
 actually bounds - not -[XCAXClient_iOS attributesForElement:attributes:error:] above.

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

 A class-level method: it only touches the XPC request timeout global, never the AX
 client, so calling it does not trigger AX subsystem initialization. The scope is
 serialized behind a dedicated lock, so overlapping calls nest/queue instead of racing
 to restore the global. The returned completion result is sampled immediately after
 `block` returns and before the previous value is restored.

 Returns YES if `block` returned within `timeout`, NO otherwise.
 */
+ (BOOL)withXPCRequestTimeout:(NSTimeInterval)timeout do:(void (^)(void))block;

/**
 Runs `block` synchronously with the XCTest application-state timeout (the private
 `_XCTApplicationStateTimeout`/`_XCTSetApplicationStateTimeout` globals) temporarily
 set to `timeout`, restoring the previous value once `block` returns (even if it
 throws). Defaults to 60 seconds, though it may be pre-seeded once from a
 NSUserDefaults override the first time it is read, before any of this process's own
 +withApplicationStateTimeout:do: calls run.

 Unlike AXTimeout/the XPC request timeout above, this one is not scoped to a single
 request/response round trip - it bounds `[XCTWaiter waitForExpectations:timeout:]`
 inside `-[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:...]`,
 which WDA's own XCUIApplicationProcess+FBQuiescence.m swizzle already targets for the
 per-tap pre/post-event quiescence wait. That wait is gated by a *compound OR*
 expectation over two independently-notified flags - `eventLoopHasIdled` and (when
 requested) `animationsHaveFinished` - so it can return as soon as either one changes,
 not necessarily both; this timeout only bounds how long that race is allowed to run
 before giving up on both. The same global also bounds XCTest's app-launch/foreground
 state-transition waits (see -[FBSessionCommands launchApplication:...],
 +[FBSessionCommands openDeepLink:withApplication:timeout:]), which are a different,
 non-quiescence consumer of this same timeout.

 A class-level method: it only touches the application-state timeout global, never the
 AX client, so calling it does not trigger AX subsystem initialization. The scope is
 serialized behind a dedicated lock, so overlapping calls nest/queue instead of racing
 to restore the global. The returned completion result is sampled immediately after
 `block` returns and before the previous value is restored.

 Returns YES if `block` returned within `timeout`, NO otherwise.
 */
+ (BOOL)withApplicationStateTimeout:(NSTimeInterval)timeout do:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
