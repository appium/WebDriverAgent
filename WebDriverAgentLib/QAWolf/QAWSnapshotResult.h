//
//  QAWSnapshotResult.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 09/09/25.
//

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

@interface QAWSnapshotResult : NSObject
@property (nonatomic, strong, nullable) id<FBXCElementSnapshot> snapshot;
@property (nonatomic, strong, nullable) NSException *exception;
@property (nonatomic, readonly) BOOL isSuccess;

+ (instancetype _Nonnull )resultWithSnapshot:(id<FBXCElementSnapshot> _Nonnull)snapshot;
+ (instancetype _Nonnull )resultWithException:(NSException * _Nonnull)exception;
@end
