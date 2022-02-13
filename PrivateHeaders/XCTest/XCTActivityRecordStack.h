//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSDictionary, NSMutableArray, NSMutableDictionary;

@interface XCTActivityRecordStack : NSObject
{
    NSMutableArray *_storage;
    NSMutableDictionary *_mutableAggregationRecords;
}

- (void).cxx_destruct;
@property(readonly) NSMutableDictionary *mutableAggregationRecords; // @synthesize mutableAggregationRecords=_mutableAggregationRecords;
@property(readonly) NSMutableArray *storage; // @synthesize storage=_storage;
@property(readonly) NSDictionary *aggregationRecords;
- (id)topActivity;
- (long long)depth;
- (void)unwindRemainingActivitiesWithTestCase:(id)arg1;
- (void)didFinishActivity:(id)arg1 testCase:(id)arg2;
- (id)willStartActivityWithTitle:(id)arg1 type:(id)arg2 testCase:(id)arg3;
- (id)init;

@end

