//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCUIEventInterpolating.h"

@class NSNumber, NSString, XCPointerEvent;

@interface XCUIScrollEventInterpolator : NSObject <XCUIEventInterpolating>
{
    struct CGVector _scrollVectorAccumulator;
    XCPointerEvent *_pointerEvent;
}

@property(readonly) XCPointerEvent *pointerEvent; // @synthesize pointerEvent=_pointerEvent;
- (void).cxx_destruct;
- (id)pointerEventForInterpolationStep:(id)arg1 error:(id *)arg2;
@property(readonly, copy) NSNumber *maxInterpolationValue;
- (id)initWithPointerEvent:(id)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

