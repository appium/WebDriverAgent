//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCUIInterruptionMonitoring.h"

@class NSString;

@interface XCUIInterruptionMonitor : NSObject <XCUIInterruptionMonitoring>
{
    _Bool _didHandleUIInterruption;
    long long _platform;
}

+ (CDUnknownBlockType)defaultInterruptionHandler_iOS;
@property(readonly) long long platform; // @synthesize platform=_platform;
@property _Bool didHandleUIInterruption; // @synthesize didHandleUIInterruption=_didHandleUIInterruption;
- (_Bool)handleInterruptingElement:(id)arg1;
- (void)removeInterruptionHandlerWithIdentifier:(id)arg1;
- (id)addInterruptionHandlerWithDescription:(id)arg1 block:(CDUnknownBlockType)arg2;
- (id)initWithPlatform:(long long)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

