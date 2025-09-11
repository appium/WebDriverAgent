//
//  QAWSnapshotResult.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 09/09/25.
//

#import <Foundation/Foundation.h>

@interface QAWXMLStringResult : NSObject
@property (nonatomic, strong, nullable) NSString *xml;
@property (nonatomic, strong, nullable) NSException *exception;
@property (nonatomic, readonly) BOOL isSuccess;

+ (instancetype _Nonnull)resultWithXML:(NSString * _Nullable)xml;
+ (instancetype _Nonnull )resultWithException:(NSException * _Nonnull)exception;
@end
