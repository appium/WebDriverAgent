//
//  XCUIElementSnapshot+FBXCElementSnapshot.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 22/09/25.
//

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCUIElementSnapshotParser : NSObject

+ (id<FBXCElementSnapshot>) toFBSnapshot:(id<XCUIElementSnapshot>) snapshot;

@end

NS_ASSUME_NONNULL_END
