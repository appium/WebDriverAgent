#import "XCUIElement+FBUtilities.h"
#import "QAWSnapshotResult.h"

@interface XCUIElement (QAWSnapshotUtilities)

- (QAWSnapshotResult * _Nonnull)qaw_nativeSnapshotWithMaxDepth:(NSNumber *) maxDepth;

@end
