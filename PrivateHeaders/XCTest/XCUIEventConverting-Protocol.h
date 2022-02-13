//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSSet, XCPointerEvent;

@protocol XCUIEventConverting <NSObject>
+ (NSSet *)supportedEventTypes;
- (id <XCUIEventInterpolating>)interpolatorForPointerEvent:(XCPointerEvent *)arg1 eventSource:(struct __CGEventSource *)arg2;
- (id <XCUIEventInterpolationStepping>)interpolationStepperForPointerEvent:(XCPointerEvent *)arg1 eventSource:(struct __CGEventSource *)arg2;
- (BOOL)shouldInterpolatePointerEvent:(XCPointerEvent *)arg1;
- (id)cgEventForPointerEvent:(XCPointerEvent *)arg1 waitForConfirmation:(char *)arg2 error:(id *)arg3;
@end

