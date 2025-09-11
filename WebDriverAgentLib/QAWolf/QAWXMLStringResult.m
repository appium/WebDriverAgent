//
//  QAWSnapshotResult.m.m
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 09/09/25.
//

#import "QAWXMLStringResult.h"
#import <XCTest/XCTest.h>

@implementation QAWXMLStringResult

- (BOOL)isSuccess {
    return self.xml != nil && self.exception == nil;
}

- (instancetype)initWithXML:(NSString * _Nullable)xml {
    self = [super init];
    if (self) {
        _xml = xml;
        _exception = nil;
    }
    return self;
}

- (instancetype)initWithException:(NSException *)exception {
    self = [super init];
    if (self) {
        _xml = nil;
        _exception = exception;
    }
    return self;
}

+ (instancetype)resultWithXML:(NSString * _Nullable)xml {
    return [[self alloc] initWithXML:xml];
}

+ (instancetype)resultWithException:(NSException *)exception {
    return [[self alloc] initWithException:exception];
}

@end
