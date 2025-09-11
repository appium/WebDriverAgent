//
//  XCUIElement+QAWXML.m
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 11/09/25.
//

#import "XCUIElement+QAWXML.h"
#import "FBElement.h"
#import "FBXPath.h"
#import "FBXMLGenerationOptions.h"
#import "FBConfiguration.h"
#import "QAWXMLStringResult.h"

@implementation XCUIElement (QAWXML)

- (QAWXMLStringResult * _Nonnull)qaw_xmlStringWithOptions:(FBXMLGenerationOptions * _Nullable)options
                                      withMaxDepth:(NSNumber *)maxDepth
{
    NSNumber *originalMaxDepth = @(FBConfiguration.snapshotMaxDepth);
    [FBConfiguration setSnapshotMaxDepth:[maxDepth intValue]];

    NSString * _Nonnull xml = @"";
    NSException *caughtException = nil;

    @try {
        id<FBElement> root = (id<FBElement>) self;
        xml = [FBXPath xmlStringWithRootElement:root options:options];
    }
    @catch (NSException *exception) {
        caughtException = exception;
    }

    [FBConfiguration setSnapshotMaxDepth:[originalMaxDepth intValue]];

    if (caughtException) {
        return [QAWXMLStringResult resultWithException:caughtException];
    } else {
        return [QAWXMLStringResult resultWithXML:xml];
    }
    
}

@end
