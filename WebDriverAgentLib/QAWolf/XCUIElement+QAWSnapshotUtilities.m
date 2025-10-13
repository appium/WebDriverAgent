#import <XCTest/XCTest.h>
#import "FBConfiguration.h"
#import "XCUIElement+FBUtilities.h"
#import "QAWSnapshotResult.h"
#import "FBXPath.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement.h"
#import "FBElementHelpers.h"
#import "FBLogger.h"

@implementation XCUIElement (QAWSnapshotUtilities)

- (QAWSnapshotResult * _Nonnull)qaw_snapshotWithMaxDepth:(NSNumber *)maxDepth {
  NSNumber *originalMaxDepth = @(FBConfiguration.snapshotMaxDepth);
  

  id<FBXCElementSnapshot> snapshot = nil;
  NSException *caughtException = nil;
  
  id<FBElement> root = (id<FBElement>)self;

  @try {
    [FBLogger logFmt:@"Waiting for element to become stable."];
    [self waitUntilStableWithElement:root];
    [FBLogger logFmt:@"Element is stable."];
    [FBLogger logFmt:@"Updating snapshot depth to: %d", [maxDepth intValue]];
    //[FBConfiguration setSnapshotMaxDepth:[maxDepth intValue]];
    [FBLogger logFmt:@"Taking snapshot..."];
    snapshot = [self snapshotWithRoot:root
                          useNative:FBConfiguration.includeHittableInPageSource];
    [FBLogger logFmt:@"Snapshot taken."];
    //[FBLogger logFmt:@"Restoring snapshot depth to original value: %d", [originalMaxDepth intValue]];
    [FBConfiguration setSnapshotMaxDepth:[originalMaxDepth intValue]];
    [FBLogger logFmt:@"Restored original snapshot max depth"];
  }
  @catch (NSException *exception) {
    caughtException = exception;
  }

  if (caughtException) {
      return [QAWSnapshotResult resultWithException:caughtException];
  } else {
      return [QAWSnapshotResult resultWithSnapshot:snapshot];
  }
}

/**
  Extracted from FBXPath. Waits for element to be stable based on session configuration.
 */
- (void)waitUntilStableWithElement:(id<FBElement>)root
{
  if ([root isKindOfClass:XCUIElement.class]) {
    [FBLogger logFmt:@"Element is of XCUIElement type. Waiting for element stability. Timeout: %f", FBConfiguration.animationCoolOffTimeout];
    // If the app is not idle state while we retrieve the visiblity state
    // then the snapshot retrieval operation might freeze and time out
    [[(XCUIElement *)root application] fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  } else {
    [FBLogger logFmt:@"Element is not of XCUIElement type. Skipping stability wait."];
  }
}

/**
  Extracted from FBXPath. Takes element snapshot based on session configuration.
 */
- (id<FBXCElementSnapshot>)snapshotWithRoot:(id<FBElement>)root
                                  useNative:(BOOL)useNative
{
  [FBLogger logFmt:@"Started snapshot process."];
  if (![root isKindOfClass:XCUIElement.class]) {
    [FBLogger logFmt:@"Element is already a snapshot.It has type FBXCElementSnapshot, skipping."];
    return (id<FBXCElementSnapshot>)root;
  }

  if (useNative) {
    [FBLogger logFmt:@"useNative is true, taking native snapshot."];
    return [(XCUIElement *)root fb_nativeSnapshot];
  }
  
  if ([root isKindOfClass:XCUIApplication.class]) {
    [FBLogger logFmt:@"Taking standard snapshot"];
    return [(XCUIElement *)root fb_standardSnapshot];
  }
  
  [FBLogger logFmt:@"Taking custom snapshot"];
  return [(XCUIElement *)root fb_customSnapshot];
}

@end
