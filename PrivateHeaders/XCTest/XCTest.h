//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSString, XCTestObservationCenter, XCTestRun;

@interface XCTest : NSObject
{
    XCTestRun *_testRun;
    XCTestObservationCenter *_observationCenter;
}

+ (id)languageAgnosticTestClassNameForTestClass:(Class)arg1;
- (void).cxx_destruct;
- (long long)defaultExecutionOrderCompare:(id)arg1;
@property(readonly) NSString *nameForLegacyLogging;
@property(readonly) NSString *languageAgnosticTestMethodName;
@property(readonly) NSString *languageAgnosticTestClassName;
- (_Bool)tearDownWithError:(id *)arg1;
- (void)tearDown;
- (void)setUp;
- (_Bool)setUpWithError:(id *)arg1;
- (void)runTest;
- (void)performTest:(id)arg1;
@property(retain) XCTestObservationCenter *observationCenter; // @synthesize observationCenter=_observationCenter;
@property(readonly) XCTestRun *testRun; // @synthesize testRun=_testRun;
@property(readonly) Class testRunClass;
@property(readonly) Class _requiredTestRunBaseClass;
@property(readonly, copy) NSString *name;
@property(readonly) unsigned long long testCaseCount;
@property(readonly) NSString *_methodNameForReporting;
@property(readonly) NSString *_classNameForReporting;
- (void)removeTestsWithNames:(id)arg1;

@end

