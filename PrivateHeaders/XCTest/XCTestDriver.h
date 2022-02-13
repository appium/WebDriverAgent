//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCTRunnerIDESessionDelegate.h"

@class NSBundle, NSString, NSURL, NSUUID, XCTFuture, XCTPromise, XCTRunnerIDESession, XCTestConfiguration;

@interface XCTestDriver : NSObject <XCTRunnerIDESessionDelegate>
{
    XCTRunnerIDESession *_ideSession;
    NSURL *_testBundleURLFromEnvironment;
    NSUUID *_sessionIdentifierFromEnvironment;
    NSURL *_testConfigurationURLFromEnvironment;
    CDUnknownBlockType _daemonSessionProvider;
    XCTestConfiguration *_testConfiguration;
    NSBundle *_testBundle;
    id _testBundlePrincipalClassInstance;
    XCTFuture *_testRunSessionFuture;
    XCTPromise *_testRunSessionPromise;
}

+ (_Bool)environmentSpecifiesTestConfiguration;
+ (_Bool)shouldSkipInitialBundleLoadBeforeXCTestMain;
+ (id)testBundleURLFromEnvironment;
- (void).cxx_destruct;
@property(retain) XCTPromise *testRunSessionPromise; // @synthesize testRunSessionPromise=_testRunSessionPromise;
@property(retain) XCTFuture *testRunSessionFuture; // @synthesize testRunSessionFuture=_testRunSessionFuture;
@property(retain) id testBundlePrincipalClassInstance; // @synthesize testBundlePrincipalClassInstance=_testBundlePrincipalClassInstance;
@property(retain) NSBundle *testBundle; // @synthesize testBundle=_testBundle;
@property(retain) XCTestConfiguration *testConfiguration; // @synthesize testConfiguration=_testConfiguration;
@property(readonly, copy) CDUnknownBlockType daemonSessionProvider; // @synthesize daemonSessionProvider=_daemonSessionProvider;
@property(readonly, copy) NSURL *testConfigurationURLFromEnvironment; // @synthesize testConfigurationURLFromEnvironment=_testConfigurationURLFromEnvironment;
@property(readonly, copy) NSUUID *sessionIdentifierFromEnvironment; // @synthesize sessionIdentifierFromEnvironment=_sessionIdentifierFromEnvironment;
@property(readonly, copy) NSURL *testBundleURLFromEnvironment; // @synthesize testBundleURLFromEnvironment=_testBundleURLFromEnvironment;
@property(retain) XCTRunnerIDESession *ideSession; // @synthesize ideSession=_ideSession;
- (id)testWorkerForIDESession:(id)arg1;
- (void)IDESessionDidDisconnect:(id)arg1;
- (Class)_declaredPrincipalClassFromTestBundle:(id)arg1;
- (void)_createTestBundlePrincipalClassInstance;
- (id)_loadTestBundleFromURL:(id)arg1 error:(id *)arg2;
- (void)_reportBootstrappingFailure:(id)arg1;
- (id)_prepareIDESessionWithIdentifier:(id)arg1 exitCode:(int *)arg2;
- (int)_runTests;
- (void)_configureGlobalState;
- (int)_prepareTestConfigurationAndIDESession;
- (int)run;
- (id)initWithTestConfiguration:(id)arg1;
- (id)initWithTestBundleURLFromEnvironment:(id)arg1 sessionIdentifierFromEnvironment:(id)arg2 testConfigurationURLFromEnvironment:(id)arg3 testConfiguration:(id)arg4 daemonSessionProvider:(CDUnknownBlockType)arg5;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

