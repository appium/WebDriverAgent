//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCTRunnerAutomationSession.h"

@class NSString, NSXPCConnection, XCTCapabilities;

@interface XCTRunnerAutomationSession : NSObject <XCTRunnerAutomationSession>
{
    int _connectionPid;
    NSXPCConnection *_connection;
    XCTCapabilities *_remoteInterfaceCapabilities;
}

+ (id)legacyCapabilitiesForOSVersion:(CDStruct_2ec95fd7)arg1 platform:(unsigned long long)arg2 error:(id *)arg3;
+ (id)exportedCapabilities;
+ (void)requestSessionWithEndpoint:(id)arg1 pid:(int)arg2 completion:(CDUnknownBlockType)arg3;
- (void).cxx_destruct;
@property(retain) XCTCapabilities *remoteInterfaceCapabilities; // @synthesize remoteInterfaceCapabilities=_remoteInterfaceCapabilities;
@property(readonly) int connectionPid; // @synthesize connectionPid=_connectionPid;
@property(readonly) NSXPCConnection *connection; // @synthesize connection=_connection;
- (_Bool)isMacCatalystForPID:(int)arg1;
@property(readonly) _Bool hasBannerNotificationIsStickyAttribute;
@property(readonly) _Bool usePointTransformationsForFrameConversions;
@property(readonly) _Bool supportsHostedViewCoordinateTransformations;
- (id)parameterizedAttribute:(id)arg1 forElement:(id)arg2 parameter:(id)arg3 error:(id *)arg4;
- (id)valuesForPrivilegedAttributes:(id)arg1 forElement:(id)arg2 error:(id *)arg3;
@property(readonly) _Bool providesValuesForPrivilegedAttributes;
- (id)attributesForElement:(id)arg1 attributes:(id)arg2 error:(id *)arg3;
@property(readonly) _Bool allowsRemoteAccess;
@property(readonly) _Bool isMacCatalyst;
- (void)notifyWhenAnimationsAreIdle:(CDUnknownBlockType)arg1;
@property(readonly) _Bool supportsAnimationsIdleNotifications;
- (void)notifyWhenMainRunLoopIsIdle:(CDUnknownBlockType)arg1;
@property(readonly) _Bool supportsMainRunLoopIdleNotifications;
@property(readonly) _Bool supportsFetchingAttributesForElement;
- (id)matchesForQuery:(id)arg1 error:(id *)arg2;
- (id)initWithConnection:(id)arg1 pid:(int)arg2 remoteInterfaceCapabilities:(id)arg3;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

