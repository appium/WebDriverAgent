//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSError;

@protocol XCUIEventRequestDelegate <NSObject>
- (void)eventRequest:(id <XCUIEventGeneratorRequest>)arg1 didFailWithError:(NSError *)arg2;
- (void)eventRequestDidFinishPostingEvents:(id <XCUIEventGeneratorRequest>)arg1;
- (void)eventRequestWasInvalidated:(id <XCUIEventGeneratorRequest>)arg1;
@end

