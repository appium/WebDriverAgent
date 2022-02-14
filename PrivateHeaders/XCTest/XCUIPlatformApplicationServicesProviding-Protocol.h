//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSArray, NSDictionary, NSString, XCUIApplicationSpecifier;

@protocol XCUIPlatformApplicationServicesProviding <NSObject>
@property __weak id <XCUIApplicationPlatformServicesProviderDelegate> platformApplicationServicesProviderDelegate;
- (void)requestApplicationSpecifierForPID:(int)arg1 reply:(void (^)(XCUIApplicationSpecifier *, NSError *))arg2;
- (void)terminateApplicationWithBundleID:(NSString *)arg1 pid:(int)arg2 completion:(void (^)(_Bool, NSError *))arg3;
- (void)launchApplicationWithPath:(NSString *)arg1 bundleID:(NSString *)arg2 arguments:(NSArray *)arg3 environment:(NSDictionary *)arg4 completion:(void (^)(_Bool, NSError *))arg5;
- (void)beginMonitoringApplicationWithSpecifier:(XCUIApplicationSpecifier *)arg1;
@end

