//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Nov 29 2017 14:55:25).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

@interface XCUIScreen()
{
  _Bool _isMainScreen;
  int _displayID;
}
@property(readonly) _Bool isMainScreen; // @synthesize isMainScreen=_isMainScreen;
@property(readonly) int displayID; // @synthesize displayID=_displayID;

- (id)_clippedScreenshotData:(id)arg1 quality:(long long)arg2 rect:(struct CGRect)arg3 scale:(double)arg4;
- (id)_screenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2 error:(id *)arg3;
- (id)screenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2 error:(id *)arg3;
- (id)screenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2;
- (id)_modernScreenshotDataForQuality:(long long)arg1 rect:(struct CGRect)arg2 error:(id *)arg3;
- (id)screenshot;
- (id)_imageFromData:(id)arg1;
- (double)scale;
- (id)initWithDisplayID:(int)arg1 isMainScreen:(_Bool)arg2;

@end
