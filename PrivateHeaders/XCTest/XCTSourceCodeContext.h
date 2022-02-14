//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSArray, XCTSourceCodeLocation;

@interface XCTSourceCodeContext : NSObject <NSSecureCoding>
{
    NSArray *_callStack;
    XCTSourceCodeLocation *_location;
}

+ (_Bool)supportsSecureCoding;
+ (id)sourceCodeFramesFromCallStackReturnAddresses:(id)arg1;
- (void).cxx_destruct;
@property(readonly) XCTSourceCodeLocation *location; // @synthesize location=_location;
@property(readonly, copy) NSArray *callStack; // @synthesize callStack=_callStack;
- (_Bool)isEqual:(id)arg1;
- (unsigned long long)hash;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)init;
- (id)initWithLocation:(id)arg1;
- (id)initWithCallStackAddresses:(id)arg1 location:(id)arg2;
- (id)initWithCallStack:(id)arg1 location:(id)arg2;

@end

