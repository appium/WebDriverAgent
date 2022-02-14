//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "XCUIScreenshotProviding.h"

@class NSString;

@interface XCUIScreen : NSObject <XCUIScreenshotProviding>
{
    _Bool _isMainScreen;
    long long _displayID;
    id <XCUIDevice> _device;
    id <XCUIScreenDataSource> _screenDataSource;
}

+ (id)screens;
+ (id)mainScreen;
- (void).cxx_destruct;
@property(readonly) id <XCUIScreenDataSource> screenDataSource; // @synthesize screenDataSource=_screenDataSource;
@property(readonly) __weak id <XCUIDevice> device; // @synthesize device=_device;
@property(readonly) _Bool isMainScreen; // @synthesize isMainScreen=_isMainScreen;
@property(readonly) long long displayID; // @synthesize displayID=_displayID;
- (id)_screenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2 error:(id *)arg3;
- (id)screenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2 error:(id *)arg3;
- (id)screenshot;
@property(readonly) unsigned long long hash;
- (_Bool)isEqual:(id)arg1;
@property(readonly) double scale;
@property(readonly, copy) NSString *description;
- (id)initWithDisplayID:(long long)arg1 isMainScreen:(_Bool)arg2 device:(id)arg3 screenDataSource:(id)arg4;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly) Class superclass;

@end

