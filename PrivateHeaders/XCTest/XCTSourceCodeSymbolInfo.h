//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSString, XCTSourceCodeLocation;

@interface XCTSourceCodeSymbolInfo : NSObject <NSSecureCoding>
{
    NSString *_imageName;
    NSString *_symbolName;
    XCTSourceCodeLocation *_location;
}

+ (_Bool)supportsSecureCoding;
- (void).cxx_destruct;
@property(readonly) XCTSourceCodeLocation *location; // @synthesize location=_location;
@property(readonly, copy) NSString *symbolName; // @synthesize symbolName=_symbolName;
@property(readonly, copy) NSString *imageName; // @synthesize imageName=_imageName;
- (_Bool)isEqual:(id)arg1;
- (unsigned long long)hash;
- (id)description;
- (id)initWithCoder:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithImageName:(id)arg1 symbolName:(id)arg2 location:(id)arg3;

@end

