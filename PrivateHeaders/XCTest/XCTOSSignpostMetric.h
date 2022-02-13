//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

#import "XCTMetric.h"
#import "XCTMetric_Private.h"

@class MXMOSSignpostMetric, NSString;

@interface XCTOSSignpostMetric : NSObject <XCTMetric_Private, XCTMetric>
{
    NSString *_instrumentationName;
    MXMOSSignpostMetric *__underlyingMetric;
}

+ (id)scrollDraggingMetric;
+ (id)scrollDecelerationMetric;
+ (id)customNavigationTransitionMetric;
+ (id)navigationTransitionMetric;
+ (id)applicationLaunchMetric;
- (void).cxx_destruct;
@property(retain, nonatomic) MXMOSSignpostMetric *_underlyingMetric; // @synthesize _underlyingMetric=__underlyingMetric;
@property(readonly, nonatomic) NSString *instrumentationName; // @synthesize instrumentationName=_instrumentationName;
- (id)reportMeasurementsFromStartTime:(id)arg1 toEndTime:(id)arg2 error:(id *)arg3;
- (void)didStopMeasuringAtTimestamp:(id)arg1;
- (void)didStartMeasuringAtTimestamp:(id)arg1;
- (void)willBeginMeasuringAtEstimatedTimestamp:(id)arg1;
- (void)prepareToMeasureWithOptions:(id)arg1;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (id)initWithUnderlyingMetric:(id)arg1;
- (id)initWithSubsystem:(id)arg1 category:(id)arg2 name:(id)arg3;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

