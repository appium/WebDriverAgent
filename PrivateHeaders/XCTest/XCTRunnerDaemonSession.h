//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "XCTestManager_TestsInterface-Protocol.h"
#import "XCUIApplicationAutomationSessionProviding-Protocol.h"
#import "XCUIDeviceEventAndStateInterface-Protocol.h"
#import "XCUIEventSynthesizing-Protocol.h"
#import "XCUIPlatformApplicationServicesProviding-Protocol.h"
#import "XCUIRemoteAccessibilityInterface-Protocol.h"
#import "XCUIRemoteSiriInterface-Protocol.h"
#import "XCUIResetAuthorizationStatusOfProtectedResourcesInterface-Protocol.h"

@class XCTestManager_ManagerInterface, XCUIApplicationPlatformServicesProviderDelegate, XCUIAXNotificationHandling;
@class XCUIAXNotificationHandling;

@class NSMutableDictionary, NSString, NSXPCConnection, XCTCapabilities;

@interface XCTRunnerDaemonSession : NSObject <XCUIRemoteSiriInterface, XCUIDeviceEventAndStateInterface, XCUIPlatformApplicationServicesProviding, XCUIApplicationAutomationSessionProviding, XCUIResetAuthorizationStatusOfProtectedResourcesInterface, XCTestManager_TestsInterface, XCUIRemoteAccessibilityInterface, XCUIEventSynthesizing>
{
    double _implicitEventConfirmationIntervalForCurrentContext;
    NSXPCConnection *_connection;
    XCTCapabilities *_remoteInterfaceCapabilities;
    XCUIApplicationPlatformServicesProviderDelegate *_platformApplicationServicesProviderDelegate;
    XCUIAXNotificationHandling *_axNotificationHandler;
    NSObject<OS_dispatch_queue> *_queue;
    NSMutableDictionary *_invalidationHandlers;
}

+ (id)daemonCapabilitiesForProtocolVersion:(unsigned long long)arg1 platform:(unsigned long long)arg2 error:(id *)arg3;
+ (id)capabilities;
+ (void)legacyCapabilitiesForDaemonConnection:(id)arg1 completion:(CDUnknownBlockType)arg2;
+ (void)modernCapabilitiesForDaemonConnection:(id)arg1 completion:(CDUnknownBlockType)arg2;
+ (void)capabilitiesForDaemonConnection:(id)arg1 completion:(CDUnknownBlockType)arg2;
+ (void)sessionWithConnection:(id)arg1 completion:(CDUnknownBlockType)arg2;
+ (void)initiateSharedSessionWithCompletion:(CDUnknownBlockType)arg1;
+ (id)sharedSession;
+ (id)sharedSessionPromiseAndImplicitlyInitiateSession:(_Bool)arg1;
+ (id)automationSessionBlacklist;
//- (void).cxx_destruct;
@property(retain) NSMutableDictionary *invalidationHandlers; // @synthesize invalidationHandlers=_invalidationHandlers;
@property(readonly) NSObject<OS_dispatch_queue> *queue; // @synthesize queue=_queue;
@property __weak XCUIAXNotificationHandling *axNotificationHandler; // @synthesize axNotificationHandler=_axNotificationHandler;
@property __weak XCUIApplicationPlatformServicesProviderDelegate *platformApplicationServicesProviderDelegate; // @synthesize platformApplicationServicesProviderDelegate=_platformApplicationServicesProviderDelegate;
@property(readonly) XCTCapabilities *remoteInterfaceCapabilities; // @synthesize remoteInterfaceCapabilities=_remoteInterfaceCapabilities;
@property(readonly) NSXPCConnection *connection; // @synthesize connection=_connection;
- (void)requestDTServiceHubConnectionWithReply:(CDUnknownBlockType)arg1;
- (void)enableFauxCollectionViewCells:(CDUnknownBlockType)arg1;
- (void)setLocalizableStringsDataGatheringEnabled:(_Bool)arg1 reply:(CDUnknownBlockType)arg2;
- (void)loadAccessibilityWithTimeout:(double)arg1 reply:(CDUnknownBlockType)arg2;
- (void)setAXTimeout:(double)arg1 reply:(CDUnknownBlockType)arg2;
@property double implicitEventConfirmationIntervalForCurrentContext; // @synthesize implicitEventConfirmationIntervalForCurrentContext=_implicitEventConfirmationIntervalForCurrentContext;
- (id)synthesizeEvent:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)requestElementAtPoint:(struct CGPoint)arg1 reply:(CDUnknownBlockType)arg2;
- (void)fetchParameterizedAttribute:(id)arg1 forElement:(id)arg2 parameter:(id)arg3 reply:(CDUnknownBlockType)arg4;
- (void)setAttribute:(id)arg1 value:(id)arg2 element:(id)arg3 reply:(CDUnknownBlockType)arg4;
- (void)fetchAttributes:(id)arg1 forElement:(id)arg2 reply:(CDUnknownBlockType)arg3;
- (void)fetchSnapshotForElement:(id)arg1 attributes:(id)arg2 parameters:(id)arg3 reply:(CDUnknownBlockType)arg4;
- (void)requestSnapshotForElement:(id)arg1 attributes:(id)arg2 parameters:(id)arg3 reply:(CDUnknownBlockType)arg4;
- (void)snapshotForElement:(id)arg1 attributes:(id)arg2 parameters:(id)arg3 reply:(CDUnknownBlockType)arg4;
@property(readonly) _Bool axNotificationsIncludeElement;
@property(readonly) _Bool useLegacySnapshotPath;
- (void)performAccessibilityAction:(id)arg1 onElement:(id)arg2 value:(id)arg3 reply:(CDUnknownBlockType)arg4;
- (void)unregisterForAccessibilityNotification:(int)arg1 registrationToken:(id)arg2 reply:(CDUnknownBlockType)arg3;
- (void)registerForAccessibilityNotification:(int)arg1 reply:(CDUnknownBlockType)arg2;
- (void)requestSpindumpWithSpecification:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)requestScreenshotOfScreenWithID:(long long)arg1 withRect:(struct CGRect)arg2 formatUTI:(id)arg3 compressionQuality:(double)arg4 withReply:(CDUnknownBlockType)arg5;
- (void)requestBackgroundAssertionForPID:(int)arg1 reply:(CDUnknownBlockType)arg2;
- (void)requestIDEConnectionTransportForSessionIdentifier:(id)arg1 reply:(CDUnknownBlockType)arg2;
- (void)_XCT_receivedAccessibilityNotification:(int)arg1 fromElement:(id)arg2 payload:(id)arg3;
- (void)_XCT_receivedAccessibilityNotification:(int)arg1 withPayload:(id)arg2;
- (void)_XCT_applicationWithBundleID:(id)arg1 didUpdatePID:(int)arg2 andState:(unsigned long long)arg3;
@property(readonly) _Bool useLegacyScreenshotPath;
@property(readonly) _Bool usePointTransformationsForFrameConversions;
@property(readonly) _Bool useLegacyEventCoordinateTransformationPath;
- (_Bool)requestPressureEventsSupportedOrError:(id *)arg1;
@property(readonly) XCTestManager_ManagerInterface *daemonProxy;
- (void)unregisterInvalidationHandlerWithToken:(id)arg1;
- (id)registerInvalidationHandler:(CDUnknownBlockType)arg1;
- (void)_reportInvalidation;
- (id)initWithConnection:(id)arg1 remoteInterfaceCapabilities:(id)arg2;
- (void)dealloc;
@property(readonly) _Bool supportsInjectingVoiceRecognitionAudioInputPaths;
- (void)injectVoiceRecognitionAudioInputPaths:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)injectAssistantRecognitionStrings:(id)arg1 completion:(CDUnknownBlockType)arg2;
@property(readonly) _Bool supportsStartingSiriUIRequestWithAudioFileURL;
- (void)startSiriUIRequestWithAudioFileURL:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)startSiriUIRequestWithText:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)requestSiriEnabledStatus:(CDUnknownBlockType)arg1;
- (void)updateDeviceOrientation:(long long)arg1 completion:(CDUnknownBlockType)arg2;
- (void)performDeviceEvent:(id)arg1 completion:(CDUnknownBlockType)arg2;
- (void)getDeviceOrientationWithCompletion:(CDUnknownBlockType)arg1;
- (void)requestApplicationSpecifierForPID:(int)arg1 reply:(CDUnknownBlockType)arg2;
- (void)fetchAttributesForElement:(id)arg1 attributes:(id)arg2 reply:(CDUnknownBlockType)arg3;
- (void)terminateApplicationWithBundleID:(id)arg1 pid:(int)arg2 completion:(CDUnknownBlockType)arg3;
- (void)launchApplicationWithPath:(id)arg1 bundleID:(id)arg2 arguments:(id)arg3 environment:(id)arg4 completion:(CDUnknownBlockType)arg5;
- (void)beginMonitoringApplicationWithSpecifier:(id)arg1;
- (void)requestAutomationSessionBlacklist:(CDUnknownBlockType)arg1;
- (void)requestAutomationSessionForTestTargetWithPID:(int)arg1 preferredBackendPath:(id)arg2 reply:(CDUnknownBlockType)arg3;
@property(readonly) long long applicationAutomationSessionSupport;
- (_Bool)resetAuthorizationStatusForBundleIdentifier:(id)arg1 resourceIdentifier:(id)arg2 error:(id *)arg3;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

