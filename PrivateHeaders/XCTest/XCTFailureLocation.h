//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSString;

@interface XCTFailureLocation : NSObject
{
    NSString *_filePath;
    unsigned long long _lineNumber;
}

- (void).cxx_destruct;
@property(readonly) unsigned long long lineNumber; // @synthesize lineNumber=_lineNumber;
@property(readonly, copy) NSString *filePath; // @synthesize filePath=_filePath;
- (id)initWithFilePath:(id)arg1 lineNumber:(unsigned long long)arg2;

@end

