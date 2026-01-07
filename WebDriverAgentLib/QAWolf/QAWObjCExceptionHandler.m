//
//  ObjCExceptionHandler.m
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 06/01/26.
//
#import "QAWObjCExceptionHandler.h"

@implementation QAWObjCExceptionHandler

+ (id _Nullable)tryBlock:(ObjCExceptionBlock)block
                    error:(NSError * _Nullable * _Nullable)error {
    @try {
        return block();
    }
    @catch (NSException *exception) {
        if (error != NULL) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = exception.reason ?: @"Unknown exception";
            userInfo[@"exceptionName"] = exception.name;
            
            if (exception.userInfo) {
                userInfo[@"exceptionUserInfo"] = exception.userInfo;
            }
            
            if (exception.callStackSymbols) {
                userInfo[@"callStackSymbols"] = exception.callStackSymbols;
            }
            
            *error = [NSError errorWithDomain:@"QAWObjCExceptionDomain"
                                         code:-1
                                     userInfo:userInfo];
        }
        return nil;
    }
}

@end
