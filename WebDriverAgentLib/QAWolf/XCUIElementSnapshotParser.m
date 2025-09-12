//
//  XCUIElementSnapshot+FBXCElementSnapshotWrapper.m.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 22/09/25.
//



#import "XCUIElementSnapshotParser.h"
@implementation XCUIElementSnapshotParser

+ (id<FBXCElementSnapshot>) toFBSnapshot:(id<XCUIElementSnapshot>) snapshot {
    return (id<FBXCElementSnapshot>) snapshot;
}

@end

