//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "NSObject.h"

@class NSArray, XCUITransformParameters;

@interface XCUIRectTransformationRequest : NSObject
{
    XCUITransformParameters *_transformParameters;
    struct CGRect _rect;
}

+ (id)rectTransformationRequestWithRect:(struct CGRect)arg1 parameters:(id)arg2;
- (void).cxx_destruct;
@property(readonly) XCUITransformParameters *transformParameters; // @synthesize transformParameters=_transformParameters;
@property(readonly) struct CGRect rect; // @synthesize rect=_rect;
@property(readonly) NSArray *axParameterRepresentation;

@end

