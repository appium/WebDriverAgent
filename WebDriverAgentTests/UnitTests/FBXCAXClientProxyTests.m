/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "CDStructures.h"
#import "FBXCAXClientProxy.h"

@interface FBXCAXClientProxyTests : XCTestCase
@end

@implementation FBXCAXClientProxyTests

- (void)testApplicationStateTimeoutSetsValueDuringBlockAndRestoresAfter
{
  double original = _XCTApplicationStateTimeout();
  __block double observed = -1;
  BOOL completed = [FBXCAXClientProxy withApplicationStateTimeout:12.5 do:^{
    observed = _XCTApplicationStateTimeout();
  }];
  XCTAssertTrue(completed);
  XCTAssertEqual(observed, 12.5);
  XCTAssertEqual(_XCTApplicationStateTimeout(), original);
}

- (void)testApplicationStateTimeoutNestedCallsRestoreCorrectly
{
  double original = _XCTApplicationStateTimeout();
  [FBXCAXClientProxy withApplicationStateTimeout:20 do:^{
    XCTAssertEqual(_XCTApplicationStateTimeout(), 20);
    [FBXCAXClientProxy withApplicationStateTimeout:5 do:^{
      XCTAssertEqual(_XCTApplicationStateTimeout(), 5);
    }];
    XCTAssertEqual(_XCTApplicationStateTimeout(), 20);
  }];
  XCTAssertEqual(_XCTApplicationStateTimeout(), original);
}

- (void)testApplicationStateTimeoutOverlappingCallsRestoreOriginalValue
{
  double original = _XCTApplicationStateTimeout();
  NSInteger iterations = 50;
  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
  for (NSInteger i = 0; i < iterations; i++) {
    dispatch_group_async(group, queue, ^{
      [FBXCAXClientProxy withApplicationStateTimeout:10 + (double)i do:^{
        usleep(500);
      }];
    });
  }
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(_XCTApplicationStateTimeout(), original);
}

- (void)testXPCRequestTimeoutSetsValueDuringBlockAndRestoresAfter
{
  double original = _XCTXPCRequestTimeout();
  __block double observed = -1;
  BOOL completed = [FBXCAXClientProxy withXPCRequestTimeout:7.5 do:^{
    observed = _XCTXPCRequestTimeout();
  }];
  XCTAssertTrue(completed);
  XCTAssertEqual(observed, 7.5);
  XCTAssertEqual(_XCTXPCRequestTimeout(), original);
}

- (void)testXPCRequestTimeoutOverlappingCallsRestoreOriginalValue
{
  double original = _XCTXPCRequestTimeout();
  NSInteger iterations = 50;
  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
  for (NSInteger i = 0; i < iterations; i++) {
    dispatch_group_async(group, queue, ^{
      [FBXCAXClientProxy withXPCRequestTimeout:10 + (double)i do:^{
        usleep(500);
      }];
    });
  }
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(_XCTXPCRequestTimeout(), original);
}

@end
