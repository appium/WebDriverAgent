//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSException, NSString, XCTFailureLocation;

@interface XCTFailure : NSObject
{
    NSString *_description;
    XCTFailureLocation *_location;
    NSException *_exception;
}

+ (id)failureWithException:(id)arg1 description:(id)arg2;
+ (id)failureWithException:(id)arg1;
+ (id)failureWithDescription:(id)arg1;
- (void).cxx_destruct;
@property(readonly) NSException *exception; // @synthesize exception=_exception;
@property(retain) XCTFailureLocation *location; // @synthesize location=_location;
@property(readonly, copy) NSString *description; // @synthesize description=_description;
- (id)initWithDescription:(id)arg1 location:(id)arg2 exception:(id)arg3;

@end

