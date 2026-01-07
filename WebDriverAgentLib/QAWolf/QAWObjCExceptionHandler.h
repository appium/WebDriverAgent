//
//  ObjCExceptionHandler.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 06/01/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^ObjCExceptionBlock)(void);

@interface QAWObjCExceptionHandler : NSObject

/**
 Executes a block and captures any Objective-C exceptions.
 
 @param block The block to execute
 @param error Output parameter for any exception that occurs
 @return The return value from the block, or nil if an exception occurred
 */
+ (id _Nullable)tryBlock:(ObjCExceptionBlock)block
                    error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
