//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "XCTTestWorker.h"

@class NSString, XCTBlockingQueue, XCTestConfiguration;

@interface XCTTestRunSession : NSObject <XCTTestWorker>
{
    id <XCTTestRunSessionDelegate> _delegate;
    XCTestConfiguration *_testConfiguration;
    XCTBlockingQueue *_workQueue;
}

+ (void)initialize;
- (void).cxx_destruct;
@property(retain) XCTBlockingQueue *workQueue; // @synthesize workQueue=_workQueue;
@property(retain) XCTestConfiguration *testConfiguration; // @synthesize testConfiguration=_testConfiguration;
@property __weak id <XCTTestRunSessionDelegate> delegate; // @synthesize delegate=_delegate;
- (void)shutdown;
- (void)executeTestIdentifiers:(id)arg1 skippingTestIdentifiers:(id)arg2 completionHandler:(CDUnknownBlockType)arg3 completionQueue:(id)arg4;
- (void)fetchDiscoveredTestClasses:(CDUnknownBlockType)arg1;
- (_Bool)runTestsAndReturnError:(id *)arg1;
- (_Bool)_preTestingInitialization;
- (void)resumeAppSleep:(id)arg1;
- (id)suspendAppSleep;
- (id)initWithTestConfiguration:(id)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

