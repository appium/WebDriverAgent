#import "XCUIElement+FBUtilities.h"
#import "QAWSnapshotResult.h"

@interface XCUIElement (QAWSnapshotUtilities)

- (QAWSnapshotResult * _Nonnull)qaw_snapshotWithMaxDepth:(NSNumber * _Nonnull) maxDepth;

@end
