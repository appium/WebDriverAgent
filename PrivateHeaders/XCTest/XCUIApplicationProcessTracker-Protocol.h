//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSNumber, XCUIApplicationProcess;

@protocol XCUIApplicationProcessTracker <NSObject>
- (void)setApplicationProcess:(XCUIApplicationProcess *)arg1 forToken:(NSNumber *)arg2;
- (XCUIApplicationProcess *)applicationProcessWithToken:(NSNumber *)arg1;
- (void)setApplicationProcess:(XCUIApplicationProcess *)arg1 forPID:(int)arg2;
- (XCUIApplicationProcess *)applicationProcessWithPID:(int)arg1;
- (id <XCUIElementSnapshotApplication>)monitoredApplicationWithProcessIdentifier:(int)arg1;
@end

