#import "FBConfiguration.h"
#import "XCUIElement+FBUtilities.h"
#import "QAWSnapshotResult.h"

@implementation XCUIElement (QAWSnapshotUtilities)

- (QAWSnapshotResult * _Nonnull)qaw_nativeSnapshotWithMaxDepth:(NSNumber *)maxDepth {
    NSNumber *originalMaxDepth = @(FBConfiguration.snapshotMaxDepth);
    [FBConfiguration setSnapshotMaxDepth:[maxDepth intValue]];

    id<XCUIElementSnapshot> snapshot = nil;
    NSException *caughtException = nil;

    @try {
        snapshot = (id<XCUIElementSnapshot>)[self fb_standardSnapshot];
    }
    @catch (NSException *exception) {
        caughtException = exception;
    }

    [FBConfiguration setSnapshotMaxDepth:[originalMaxDepth intValue]];

    if (caughtException) {
        return [QAWSnapshotResult resultWithException:caughtException];
    } else {
        return [QAWSnapshotResult resultWithSnapshot:snapshot];
    }
}

@end
