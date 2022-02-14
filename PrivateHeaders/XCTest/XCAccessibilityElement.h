//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

// FIXME: Probably we can remove here. instead, probably we should follow only XCElementSnapshot
// FIXME: No longer exists in Xcode 12+

@class NSString;

@interface XCAccessibilityElement : NSObject <NSCopying, NSSecureCoding>
{
    NSString *_context;
    id _payload;
    int _processIdentifier;
    struct __AXUIElement *_axElement;
    unsigned long long _elementType;
}
@property(readonly) id payload; // @synthesize payload=_payload;
@property(readonly) int processIdentifier; // @synthesize processIdentifier=_processIdentifier;
@property(readonly) const struct __AXUIElement *AXUIElement; // @synthesize AXUIElement=_axElement;
@property(readonly, getter=isNative) BOOL native;

+ (id)elementWithAXUIElement:(struct __AXUIElement *)arg1;
+ (id)elementWithProcessIdentifier:(int)arg1;
+ (id)deviceElement;
+ (id)mockElementWithProcessIdentifier:(int)arg1 payload:(id)arg2;
+ (id)mockElementWithProcessIdentifier:(int)arg1;

- (id)initWithMockProcessIdentifier:(int)arg1 payload:(id)arg2;
- (id)initWithAXUIElement:(struct __AXUIElement *)arg1;
- (id)init;

@end
