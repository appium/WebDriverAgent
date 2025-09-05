//
//  QAWSnapshotResult.m.m
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 09/09/25.
//

#import "QAWSnapshotResult.h"
#import <XCTest/XCTest.h>

@implementation QAWSnapshotResult

- (BOOL)isSuccess {
    return self.snapshot != nil && self.exception == nil;
}

- (instancetype)initWithSnapshot:(id<XCUIElementSnapshot> _Nonnull)snapshot {
    self = [super init];
    if (self) {
        _snapshot = snapshot;
        _exception = nil;
    }
    return self;
}

- (instancetype)initWithException:(NSException *)exception {
    self = [super init];
    if (self) {
        _snapshot = nil;
        _exception = exception;
    }
    return self;
}

+ (instancetype)resultWithSnapshot:(id<XCUIElementSnapshot> _Nonnull)snapshot {
    return [[self alloc] initWithSnapshot:snapshot];
}

+ (instancetype)resultWithException:(NSException *)exception {
    return [[self alloc] initWithException:exception];
}

@end
