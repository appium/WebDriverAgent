//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "XCUIEventInterpolating.h"

@class NSArray, NSError, NSNumber, NSString, XCPointerEvent, XCUIKeyboardLayout, XCUITextInputState;

@interface XCUITextEventInterpolator : NSObject <XCUIEventInterpolating>
{
    unsigned long long _keepEventFlags;
    XCUIKeyboardLayout *_keyboardLayout;
    XCUITextInputState *_previousLayoutState;
    unsigned long long _numberOfKeyUpEvents;
    NSArray *_keyboardInputs;
    NSError *_initializationError;
    // Error parsing type: {atomic_flag="_Value"AB}, name: _invalidated
    XCPointerEvent *_pointerEvent;
    struct __CGEventSource *_eventSource;
}

@property(readonly) struct __CGEventSource *eventSource; // @synthesize eventSource=_eventSource;
@property(readonly) XCPointerEvent *pointerEvent; // @synthesize pointerEvent=_pointerEvent;
- (void).cxx_destruct;
- (unsigned long long)currentKeyboardModifierFlags;
- (id)pointerEventForInterpolationStep:(id)arg1 error:(id *)arg2;
@property(readonly, copy) NSNumber *maxInterpolationValue;
- (void)invalidate;
- (id)initWithPointerEvent:(id)arg1 eventSource:(struct __CGEventSource *)arg2;
- (void)_computeKeyboardInputs;
- (void)dealloc;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

