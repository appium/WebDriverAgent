#import <XCTest/XCTest.h>
#import "FBConfiguration.h"
#import "XCUIElement+FBUtilities.h"
#import "QAWSnapshotResult.h"
#import "FBXPath.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement.h"
#import "FBElementHelpers.h"

@implementation XCUIElement (QAWSnapshotUtilities)

- (QAWSnapshotResult * _Nonnull)qaw_snapshotWithMaxDepth:(NSNumber *)maxDepth {
  NSNumber *originalMaxDepth = @(FBConfiguration.snapshotMaxDepth);
  [FBConfiguration setSnapshotMaxDepth:[maxDepth intValue]];

  id<FBXCElementSnapshot> snapshot = nil;
  NSException *caughtException = nil;
  
  id<FBElement> root = (id<FBElement>)self;

  @try {
    [self waitUntilStableWithElement:root];
    snapshot = [self snapshotWithRoot:root
                          useNative:FBConfiguration.includeHittableInPageSource];
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

/**
  Extracted from FBXPath. Waits for element to be stable based on session configuration.
 */
- (void)waitUntilStableWithElement:(id<FBElement>)root
{
  if ([root isKindOfClass:XCUIElement.class]) {
    // If the app is not idle state while we retrieve the visiblity statfbdebuge
    // then the snapshot retrieval operation might freeze and time out
    [[(XCUIElement *)root application] fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
  }
}

/**
  Extracted from FBXPath. Takes element snapshot based on session configuration.
 */
- (id<FBXCElementSnapshot>)snapshotWithRoot:(id<FBElement>)root
                                  useNative:(BOOL)useNative
{
  if (![root isKindOfClass:XCUIElement.class]) {
    return (id<FBXCElementSnapshot>)root;
  }

  if (useNative) {
    return [(XCUIElement *)root fb_nativeSnapshot];
  }
  return [root isKindOfClass:XCUIApplication.class]
    ? [(XCUIElement *)root fb_standardSnapshot]
    : [(XCUIElement *)root fb_customSnapshot];
}

@end
