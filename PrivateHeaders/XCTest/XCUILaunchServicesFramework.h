//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCUILaunchServicesFramework.h"

@class NSString;

@interface XCUILaunchServicesFramework : NSObject <XCUILaunchServicesFramework>
{
}

- (BOOL)setFrontProcess:(int)arg1 error:(id *)arg2;
- (BOOL)killApplicationWithASN:(struct __LSASN *)arg1;
- (id)applicationsMatchingQuery:(id)arg1;
- (id)informationForApplicationWithASN:(struct __LSASN *)arg1;
- (BOOL)ASN:(struct __LSASN *)arg1 equalToOtherASN:(struct __LSASN *)arg2;
@property(readonly) const struct __LSASN *frontUIApplication;
@property(readonly) const struct __LSASN *frontApplication;
- (void)unregisterForNotifications:(void *)arg1;
- (const void *)registerForNotifications:(const int *)arg1 count:(unsigned int)arg2 error:(id *)arg3 queue:(id)arg4 handler:(CDUnknownBlockType)arg5;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

