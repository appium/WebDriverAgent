//
//  XCUIElementSnapshot+XML.h
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 22/09/25.
//

#import <XCTest/XCTest.h>
#import "FBXCElementSnapshot.h"

@class FBXMLGenerationOptions;

@interface SnapshotWithId : NSObject

@property (nonatomic, strong) id<FBXCElementSnapshot> _Nonnull snapshot;
@property (nonatomic, strong) NSString * _Nonnull id;

+ (instancetype _Nonnull) wrap:(id<FBXCElementSnapshot> _Nonnull)snapshot;

@end

@interface XMLWithParentId : NSObject
@property (nonatomic, strong) NSString * _Nonnull parentId;
@property (nonatomic, strong) NSString * _Nonnull xmlString;

+ (instancetype _Nonnull )initWithParentId:(NSString * _Nonnull)parentId
                        xmlString:(NSString *_Nonnull) xmlString;

@end

@interface XMLRepresentationAndLeaves : NSObject
@property (nonatomic, strong) XMLWithParentId * _Nonnull xml;
@property (nonatomic, strong) NSArray<SnapshotWithId *> * _Nonnull leaves;

+ (instancetype _Nonnull )initWithXMLRepresentation:(XMLWithParentId * _Nonnull)xml
                        leaves:(NSArray<SnapshotWithId *> * _Nonnull) leaves;

@end

@interface QAWXML : NSObject
    
+ (XMLRepresentationAndLeaves * _Nonnull)generateXMLStringAndLeaves:(SnapshotWithId * _Nonnull)root
                        withOptions:(nullable FBXMLGenerationOptions *)options
                        withMaxDepth:(int)maxDepth
                                     parentLeafId:(nullable NSString *)parentLeafId;
@end
