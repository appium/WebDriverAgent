//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "XCUIApplicationMonitor.h"

@class NSMutableDictionary, NSMutableSet, NSObject<OS_dispatch_queue>, NSSet, NSString, XCTestConfiguration, XCUIApplicationImplDepot, XCUIApplicationRegistry;

@interface XCUIApplicationMonitor : NSObject <XCUIApplicationMonitor>
{
    XCUIApplicationRegistry *_applicationRegistry;
    NSSet *_automationSessionBlacklist;
    id <XCUIDevice> _device;
    id <XCUIPlatformApplicationServicesProviding> _platformServicesProvider;
    XCTestConfiguration *_testConfiguration;
    NSObject<OS_dispatch_queue> *_queue;
    XCUIApplicationImplDepot *_applicationImplDepot;
    NSMutableSet *_trackedBundleIDs;
    NSMutableDictionary *_applicationProcessesForPID;
    NSMutableDictionary *_applicationProcessesForToken;
    NSMutableSet *_launchedApplications;
}

+ (void)initialize;
- (void).cxx_destruct;
@property(readonly, copy) NSMutableSet *launchedApplications; // @synthesize launchedApplications=_launchedApplications;
@property(readonly, copy) NSMutableDictionary *applicationProcessesForToken; // @synthesize applicationProcessesForToken=_applicationProcessesForToken;
@property(readonly, copy) NSMutableDictionary *applicationProcessesForPID; // @synthesize applicationProcessesForPID=_applicationProcessesForPID;
@property(readonly, copy) NSMutableSet *trackedBundleIDs; // @synthesize trackedBundleIDs=_trackedBundleIDs;
@property(readonly, copy) XCUIApplicationImplDepot *applicationImplDepot; // @synthesize applicationImplDepot=_applicationImplDepot;
@property(retain) NSObject<OS_dispatch_queue> *queue; // @synthesize queue=_queue;
@property(readonly) XCTestConfiguration *testConfiguration; // @synthesize testConfiguration=_testConfiguration;
@property(readonly) id <XCUIPlatformApplicationServicesProviding> platformServicesProvider; // @synthesize platformServicesProvider=_platformServicesProvider;
@property(readonly) __weak id <XCUIDevice> device; // @synthesize device=_device;
@property(retain) XCUIApplicationRegistry *applicationRegistry; // @synthesize applicationRegistry=_applicationRegistry;
@property(readonly) NSSet *automationSessionBlacklist; // @synthesize automationSessionBlacklist=_automationSessionBlacklist;
- (void)acquireBackgroundAssertionForPID:(int)arg1 reply:(CDUnknownBlockType)arg2;
- (void)updatedApplicationStateSnapshot:(id)arg1;
- (void)_setIsTrackingForBundleID:(id)arg1;
- (_Bool)_isTrackingBundleID:(id)arg1;
- (void)processWithToken:(id)arg1 exitedWithStatus:(int)arg2;
- (void)stopTrackingProcessWithToken:(id)arg1;
- (void)crashInProcessWithBundleID:(id)arg1 path:(id)arg2 pid:(int)arg3 symbol:(id)arg4;
- (void)waitForUnrequestedTerminationOfLaunchedApplicationsWithTimeout:(double)arg1;
- (void)_waitForCrashReportOrCleanExitStatusOfApp:(id)arg1;
- (id)_appFromSet:(id)arg1 thatTransitionedToNotRunningDuringTimeInterval:(double)arg2;
- (void)terminationTrackedForApplicationProcess:(id)arg1;
- (void)launchRequestedForApplicationProcess:(id)arg1;
- (void)_terminateApplicationProcess:(id)arg1;
- (void)terminateApplicationProcess:(id)arg1 withToken:(id)arg2;
- (id)monitoredApplicationWithProcessIdentifier:(int)arg1;
- (void)setApplicationProcess:(id)arg1 forToken:(id)arg2;
- (id)applicationProcessWithToken:(id)arg1;
- (void)setApplicationProcess:(id)arg1 forPID:(int)arg2;
- (id)applicationProcessWithPID:(int)arg1;
- (id)applicationImplementationForApplicationAtPath:(id)arg1 bundleID:(id)arg2;
- (id)initWithDevice:(id)arg1 platformServicesProvider:(id)arg2 testConfiguration:(id)arg3;
- (id)initWithDevice:(id)arg1 platformServicesProvider:(id)arg2;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

