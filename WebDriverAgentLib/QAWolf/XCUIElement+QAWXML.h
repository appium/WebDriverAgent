//
//  XCUIELement+XML.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 11/09/25.
//

#import <XCTest/XCTest.h>
#import "QAWXMLStringResult.h"

NS_ASSUME_NONNULL_BEGIN

@class FBXMLGenerationOptions;

@interface XCUIElement (QAWXML)

- (QAWXMLStringResult * _Nonnull)qaw_xmlStringWithOptions:(FBXMLGenerationOptions * _Nullable)options
                                   withMaxDepth:(NSNumber *)maxDepth;

@end

NS_ASSUME_NONNULL_END

