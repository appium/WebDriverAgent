//
//  QAWSnapshotResult.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 09/09/25.
//

#import <XCTest/XCTest.h>

@interface QAWSnapshotResult : NSObject
@property (nonatomic, strong, nullable) id<XCUIElementSnapshot> snapshot;
@property (nonatomic, strong, nullable) NSException *exception;
@property (nonatomic, readonly) BOOL isSuccess;

+ (instancetype)resultWithSnapshot:(id<XCUIElementSnapshot> _Nonnull)snapshot;
+ (instancetype _Nonnull )resultWithException:(NSException * _Nonnull)exception;
@end
