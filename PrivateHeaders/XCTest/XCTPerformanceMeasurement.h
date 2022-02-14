//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSMeasurement, NSString;

@interface XCTPerformanceMeasurement : NSObject
{
    NSString *_identifier;
    NSString *_displayName;
    NSMeasurement *_value;
    double _doubleValue;
    NSString *_unitSymbol;
    long long _polarity;
}

+ (id)displayFriendlyMeasurement:(id)arg1;
- (void).cxx_destruct;
@property(readonly) long long polarity; // @synthesize polarity=_polarity;
@property(readonly, copy) NSString *unitSymbol; // @synthesize unitSymbol=_unitSymbol;
@property(readonly) double doubleValue; // @synthesize doubleValue=_doubleValue;
@property(readonly, copy) NSMeasurement *value; // @synthesize value=_value;
@property(readonly, copy) NSString *displayName; // @synthesize displayName=_displayName;
@property(readonly, copy) NSString *identifier; // @synthesize identifier=_identifier;
- (id)initWithIdentifier:(id)arg1 displayName:(id)arg2 value:(id)arg3 polarity:(long long)arg4;
- (id)initWithIdentifier:(id)arg1 displayName:(id)arg2 doubleValue:(double)arg3 unitSymbol:(id)arg4 polarity:(long long)arg5;
- (id)initWithIdentifier:(id)arg1 displayName:(id)arg2 value:(id)arg3;
- (id)initWithIdentifier:(id)arg1 displayName:(id)arg2 doubleValue:(double)arg3 unitSymbol:(id)arg4;

@end

