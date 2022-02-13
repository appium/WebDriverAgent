//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import <XCTest/XCTest.h>

#import "XCTActivity.h"
#import "XCTIssueHandling.h"
#import "XCTMemoryCheckerDelegate.h"
#import "XCTWaiterDelegate.h"

@class MXMInstrument, NSArray, NSDictionary, NSInvocation, NSMutableArray, NSMutableDictionary, NSObject<OS_dispatch_source>, NSString, NSThread, XCTAttachmentManager, XCTIssue, XCTMemoryChecker, XCTSkippedTestContext, XCTTestIdentifier, XCTWaiter, XCTestCaseRun;

@interface XCTestCase : XCTest <XCTWaiterDelegate, XCTIssueHandling, XCTMemoryCheckerDelegate, XCTActivity>
{
    _Bool _continueAfterFailure;
    _Bool __preciseTimeoutsEnabled;
    _Bool _isMeasuringMetrics;
    _Bool __didMeasureMetrics;
    _Bool __didStartMeasuring;
    _Bool __didStopMeasuring;
    _Bool _hasDequeuedTeardownBlocks;
    _Bool _hasReportedFailuresToTestCaseRun;
    _Bool _canHandleInterruptions;
    _Bool _shouldHaltWhenReceivesControl;
    _Bool _shouldSetShouldHaltWhenReceivesControl;
    _Bool _hasAttemptedToCaptureScreenshotOnFailure;
    NSInvocation *_invocation;
    double _executionTimeAllowance;
    NSArray *_activePerformanceMetricIDs;
    unsigned long long _startWallClockTime;
    struct time_value _startUserTime;
    struct time_value _startSystemTime;
    unsigned long long _measuringIteration;
    MXMInstrument *_instrument;
    long long _runLoopNestingCount;
    NSMutableArray *_teardownBlocks;
    NSMutableArray *_primaryThreadBlocks;
    XCTAttachmentManager *_attachmentManager;
    NSDictionary *_activityAggregateStatistics;
    NSObject<OS_dispatch_source> *_timeoutSource;
    unsigned long long _signpostID;
    NSThread *_primaryThread;
    XCTTestIdentifier *_identifier;
    NSMutableArray *_enqueuedIssues;
    NSMutableArray *_expectations;
    XCTWaiter *_currentWaiter;
    XCTSkippedTestContext *_skippedTestContext;
    XCTestCaseRun *_testCaseRun;
    XCTMemoryChecker *_defaultMemoryChecker;
    NSMutableDictionary *__perfMetricsForID;
}

+ (id)_baselineDictionary;
+ (_Bool)_treatMissingBaselinesAsTestFailures;
+ (id)defaultMeasureOptions;
+ (id)defaultMetrics;
+ (id)defaultPerformanceMetrics;
+ (_Bool)_reportPerformanceFailuresForLargeImprovements;
+ (id)testInvocations;
+ (_Bool)isInheritingTestCases;
+ (id)bundle;
+ (id)testCaseWithSelector:(SEL)arg1;
+ (id)testCaseWithInvocation:(id)arg1;
+ (void)tearDown;
+ (void)setUp;
+ (id)defaultTestSuite;
+ (id)allTestMethodInvocations;
+ (void)_allTestMethodInvocations:(id)arg1;
+ (id)testMethodInvocations;
+ (id)allSubclassesOutsideXCTest;
+ (id)allSubclasses;
+ (id)_allSubclasses;
- (void).cxx_destruct;
@property(retain) NSMutableDictionary *_perfMetricsForID; // @synthesize _perfMetricsForID=__perfMetricsForID;
@property(retain) XCTestCaseRun *testCaseRun; // @synthesize testCaseRun=_testCaseRun;
@property(nonatomic) _Bool shouldSetShouldHaltWhenReceivesControl; // @synthesize shouldSetShouldHaltWhenReceivesControl=_shouldSetShouldHaltWhenReceivesControl;
@property(nonatomic) _Bool shouldHaltWhenReceivesControl; // @synthesize shouldHaltWhenReceivesControl=_shouldHaltWhenReceivesControl;
@property(retain) NSThread *primaryThread; // @synthesize primaryThread=_primaryThread;
@property(copy) NSDictionary *activityAggregateStatistics; // @synthesize activityAggregateStatistics=_activityAggregateStatistics;
@property long long runLoopNestingCount; // @synthesize runLoopNestingCount=_runLoopNestingCount;
@property _Bool _didStopMeasuring; // @synthesize _didStopMeasuring=__didStopMeasuring;
@property _Bool _didStartMeasuring; // @synthesize _didStartMeasuring=__didStartMeasuring;
@property _Bool _didMeasureMetrics; // @synthesize _didMeasureMetrics=__didMeasureMetrics;
@property(nonatomic) _Bool _preciseTimeoutsEnabled; // @synthesize _preciseTimeoutsEnabled=__preciseTimeoutsEnabled;
@property(readonly) double _effectiveExecutionTimeAllowance;
- (void)_resetTimer;
- (void)_stopTimeoutTimer;
- (void)_startTimeoutTimer;
- (void)_exceededExecutionTimeAllowance;
@property unsigned long long maxDurationInMinutes;
@property double executionTimeAllowance; // @synthesize executionTimeAllowance=_executionTimeAllowance;
- (void)memoryChecker:(id)arg1 didFailWithMessages:(id)arg2 serializedMemoryGraph:(id)arg3;
- (void)assertObjectsOfType:(id)arg1 inApplication:(id)arg2 invalidAfterScope:(CDUnknownBlockType)arg3;
- (void)assertObjectsOfTypes:(id)arg1 inApplication:(id)arg2 invalidAfterScope:(CDUnknownBlockType)arg3;
- (void)assertNoLeaksInProcessWithIdentifier:(int)arg1 inScope:(CDUnknownBlockType)arg2;
- (void)assertNoLeaksInApplication:(id)arg1 inScope:(CDUnknownBlockType)arg2;
- (void)assertNoLeaksInScope:(CDUnknownBlockType)arg1;
- (void)markInvalid:(id)arg1;
- (void)assertObjectsOfType:(id)arg1 invalidAfterScope:(CDUnknownBlockType)arg2;
- (void)assertObjectsOfTypes:(id)arg1 invalidAfterScope:(CDUnknownBlockType)arg2;
- (void)assertInvalidObjectsDeallocatedAfterScope:(CDUnknownBlockType)arg1;
- (void)addAttachment:(id)arg1;
- (void)runActivityNamed:(id)arg1 inScope:(CDUnknownBlockType)arg2;
- (void)startActivityWithTitle:(id)arg1 block:(CDUnknownBlockType)arg2;
- (void)startActivityWithTitle:(id)arg1 type:(id)arg2 block:(CDUnknownBlockType)arg3;
- (void)measureMetrics:(id)arg1 automaticallyStartMeasuring:(_Bool)arg2 forBlock:(CDUnknownBlockType)arg3;
- (void)registerDefaultMetrics;
- (id)baselinesDictionaryForTest;
- (void)_logAndReportPerformanceMetrics:(id)arg1 perfMetricResultsForIDs:(id)arg2 withBaselinesForTest:(id)arg3;
- (void)_logAndReportPerformanceMetrics:(id)arg1 perfMetricResultsForIDs:(id)arg2 withBaselinesForTest:(id)arg3 defaultBaselinesForPerfMetricID:(id)arg4;
- (void)registerMetricID:(id)arg1 name:(id)arg2 unitString:(id)arg3 polarity:(long long)arg4;
- (void)registerMetricID:(id)arg1 name:(id)arg2 unitString:(id)arg3;
- (void)registerMetricID:(id)arg1 name:(id)arg2 unit:(id)arg3;
- (void)reportMetric:(id)arg1 reportFailures:(_Bool)arg2;
- (void)reportMeasurements:(id)arg1 forMetricID:(id)arg2 reportFailures:(_Bool)arg3;
- (void)_recordValues:(id)arg1 forPerformanceMetricID:(id)arg2 name:(id)arg3 unitsOfMeasurement:(id)arg4 baselineName:(id)arg5 baselineAverage:(id)arg6 maxPercentRegression:(id)arg7 maxPercentRelativeStandardDeviation:(id)arg8 maxRegression:(id)arg9 maxStandardDeviation:(id)arg10 file:(id)arg11 line:(unsigned long long)arg12;
- (void)measureWithMetrics:(id)arg1 options:(id)arg2 block:(CDUnknownBlockType)arg3;
- (void)measureWithMetrics:(id)arg1 block:(CDUnknownBlockType)arg2;
- (void)measureWithOptions:(id)arg1 block:(CDUnknownBlockType)arg2;
- (void)measureBlock:(CDUnknownBlockType)arg1;
- (void)stopMeasuring;
- (void)startMeasuring;
- (void)quiesceDidUpdate:(_Bool)arg1 error:(id)arg2;
@property(readonly) CDStruct_2ec95fd7 minimumOperatingSystemVersion;
- (void)_logMemoryGraphDataFromFilePath:(id)arg1 withTitle:(id)arg2;
- (void)_logMemoryGraphData:(id)arg1 withTitle:(id)arg2;
- (unsigned long long)numberOfTestIterationsForTestWithSelector:(SEL)arg1;
- (id)addAdditionalIterationsBasedOnOptions:(id)arg1;
- (void)afterTestIteration:(unsigned long long)arg1 selector:(SEL)arg2;
- (void)beforeTestIteration:(unsigned long long)arg1 selector:(SEL)arg2;
- (void)tearDownTestWithSelector:(SEL)arg1;
- (void)setUpTestWithSelector:(SEL)arg1;
- (void)_addTeardownBlock:(CDUnknownBlockType)arg1;
- (void)addTeardownBlock:(CDUnknownBlockType)arg1;
- (void)_purgeTeardownBlocks;
- (void)performTest:(id)arg1;
- (void)_reportFailuresAtFile:(id)arg1 line:(unsigned long long)arg2 forTestAssertionsInScope:(CDUnknownBlockType)arg3;
- (void)invokeTest;
- (Class)testRunClass;
- (Class)_requiredTestRunBaseClass;
- (void)recordIssue:(id)arg1;
@property _Bool continueAfterFailure; // @synthesize continueAfterFailure=_continueAfterFailure;
@property(retain) NSInvocation *invocation; // @synthesize invocation=_invocation;
- (void)dealloc;
@property(readonly, copy) NSString *description;
- (_Bool)isEqual:(id)arg1;
- (long long)defaultExecutionOrderCompare:(id)arg1;
- (id)nameForLegacyLogging;
@property(readonly, copy) NSString *name;
- (id)languageAgnosticTestMethodName;
- (unsigned long long)testCaseCount;
- (id)bundle;
- (id)initWithSelector:(SEL)arg1;
- (id)initWithInvocation:(id)arg1;
- (id)init;
- (void)removeUIInterruptionMonitor:(id)arg1;
- (id)addUIInterruptionMonitorWithDescription:(id)arg1 handler:(CDUnknownBlockType)arg2;
- (void)nestedWaiter:(id)arg1 wasInterruptedByTimedOutWaiter:(id)arg2;
- (void)waiter:(id)arg1 didFulfillInvertedExpectation:(id)arg2;
- (void)waiter:(id)arg1 fulfillmentDidViolateOrderingConstraintsForExpectation:(id)arg2 requiredExpectation:(id)arg3;
- (void)waiter:(id)arg1 didTimeoutWithUnfulfilledExpectations:(id)arg2;
- (id)expectationForPredicate:(id)arg1 evaluatedWithObject:(id)arg2 handler:(CDUnknownBlockType)arg3;
- (id)expectationForNotification:(id)arg1 object:(id)arg2 notificationCenter:(id)arg3 handler:(CDUnknownBlockType)arg4;
- (id)expectationForNotification:(id)arg1 object:(id)arg2 handler:(CDUnknownBlockType)arg3;
- (id)keyValueObservingExpectationForObject:(id)arg1 keyPath:(id)arg2 handler:(CDUnknownBlockType)arg3;
- (id)keyValueObservingExpectationForObject:(id)arg1 keyPath:(id)arg2 expectedValue:(id)arg3;
- (id)expectationWithDescription:(id)arg1;
- (void)waitForExpectations:(id)arg1 timeout:(double)arg2 enforceOrder:(_Bool)arg3;
- (void)waitForExpectations:(id)arg1 timeout:(double)arg2;
- (void)waitForExpectationsWithTimeout:(double)arg1 handler:(CDUnknownBlockType)arg2;
- (id)_expectationForDistributedNotification:(id)arg1 object:(id)arg2 handler:(CDUnknownBlockType)arg3;
- (id)_expectationForDarwinNotification:(id)arg1;
- (void)recordFailureWithDescription:(id)arg1 inFile:(id)arg2 atLine:(unsigned long long)arg3 expected:(_Bool)arg4;
- (void)_interruptOrMarkForLaterInterruption;
- (_Bool)_caughtUnhandledDeveloperExceptionPermittingControlFlowInterruptions:(_Bool)arg1 caughtInterruptionException:(_Bool *)arg2 whileExecutingBlock:(CDUnknownBlockType)arg3;
- (_Bool)_caughtUnhandledDeveloperExceptionPermittingControlFlowInterruptions:(_Bool)arg1 whileExecutingBlock:(CDUnknownBlockType)arg2;
- (id)_issueWithFailureScreenshotAttachedToIssue:(id)arg1;
- (void)_handleIssue:(id)arg1;
- (void)_dequeueIssues;
- (void)_enqueueIssue:(id)arg1;
- (void)_recordIssue:(id)arg1;
@property(copy) XCTIssue *candidateIssueForCurrentThread;
- (id)_storageKeyForCandidateIssue;
- (void)handleIssue:(id)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

