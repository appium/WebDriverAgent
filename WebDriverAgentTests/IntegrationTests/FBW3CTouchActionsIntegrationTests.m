/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"

#import "XCUIElement.h"
#import "XCUIDevice.h"
#import "XCUIApplication+FBTouchAction.h"
#import "FBTestMacros.h"
#import "XCUIDevice+FBRotation.h"
#import "FBRunLoopSpinner.h"
#import "FBXCodeCompatibility.h"
#import "FBW3CActionsSynthesizer.h"
#import "XCSynthesizedEventRecord.h"
#import "XCPointerEventPath.h"
#import "XCPointerEvent.h"

@interface FBW3CTouchActionsIntegrationTestsPart1 : FBIntegrationTestCase
@end

@interface FBW3CTouchActionsIntegrationTestsPart2 : FBIntegrationTestCase
@property (nonatomic) XCUIElement *pickerWheel;
@end


@implementation FBW3CTouchActionsIntegrationTestsPart1

- (void)verifyGesture:(NSArray<NSDictionary<NSString *, id> *> *)gesture orientation:(UIDeviceOrientation)orientation
{
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performW3CActions:gesture elementCache:nil error:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAlertsPage];
  });
  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];
  [self resetOrientation];
  [super tearDown];
}

- (void)testErroneousGestures
{
  NSArray<NSArray<NSDictionary<NSString *, id> *> *> *invalidGestures =
  @[
    // Empty chain
    @[],
    
    // Chain element without 'actions' key
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        },
      ],
    
    // Chain element without type
    @[@{
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
    
    // Chain element without id
    @[@{
        @"type": @"pointer",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
    
    // Chain element with empty id
    @[@{
        @"type": @"pointer",
        @"id": @"",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
    
    // Chain element with unsupported type
    @[@{
        @"type": @"key",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
    
    // Chain element with unsupported pointerType (default)
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
 
    // Chain element with unsupported pointerType (non-default)
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"pen"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @100, @"y": @100},
            ],
        },
      ],
    
    // Chain element without action item type
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"duration": @0, @"x": @1, @"y": @1},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],

    // Chain element with singe up action
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element containing action item without y coordinate
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @1},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element containing action item with an unknown type
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMoved", @"duration": @0, @"x": @1, @"y": @1},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element where pointerMove action item does not contain coordinates
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element where pointerMove action item cannot use coordinates of the previous item
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"origin": @"pointer"},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element where action items contains negative duration
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @1, @"y": @1},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @-100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    // Chain element where a leading pause is followed directly by pointerDown,
    // with no real pointerMove ever establishing a position
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pause", @"duration": @0},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],

    // Chain element where a leading pause is followed directly by a relative
    // pointerMove, with no real preceding position to be relative to
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pause", @"duration": @0},
            @{@"type": @"pointerMove", @"duration": @0, @"origin": @"pointer"},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],

    // Chain element where action items start with an incorrect one, because the correct one is canceled
    @[@{
        @"type": @"pointer",
        @"id": @"finger1",
        @"parameters": @{@"pointerType": @"touch"},
        @"actions": @[
            @{@"type": @"pointerMove", @"duration": @0, @"x": @1, @"y": @1},
            @{@"type": @"pointerCancel"},
            @{@"type": @"pointerDown"},
            @{@"type": @"pause", @"duration": @-100},
            @{@"type": @"pointerUp"},
            ],
        },
      ],
    
    ];
  
  for (NSArray<NSDictionary<NSString *, id> *> *invalidGesture in invalidGestures) {
    NSError *error;
    XCTAssertFalse([self.testedApplication fb_performW3CActions:invalidGesture elementCache:nil error:&error]);
    XCTAssertNotNil(error);
  }
}

- (void)testNothingDoesWithoutError
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[],
      },
    ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performW3CActions:gesture elementCache:nil error:&error]);
  XCTAssertNil(error);
}

- (void)testTap
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.testedApplication.buttons[FBShowAlertButtonName], @"x": @0, @"y": @0},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @100},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyGesture:gesture orientation:UIDeviceOrientationPortrait];
}

- (void)testLeadingZeroDurationPauseDoesNotAddExtraTouch
{
  // A leading pause must not defeat the down-after-move dedup logic in
  // FBPointerDownItem and make WDA synthesize a second, separate touch-down
  // for the same finger. Inspect the actual synthesized XCTest event stream
  // (without dispatching it) rather than only checking the gesture's visible
  // side effect, since a duplicate touch at the same point may still produce
  // the same visible outcome.
  XCUIElement *element = self.testedApplication.buttons[FBShowAlertButtonName];
  NSDictionary<NSString *, id> *(^sequenceWithLeadingPause)(BOOL) = ^NSDictionary<NSString *, id> *(BOOL withLeadingPause) {
    NSMutableArray<NSDictionary<NSString *, id> *> *actions = [NSMutableArray array];
    if (withLeadingPause) {
      [actions addObject:@{@"type": @"pause", @"duration": @0}];
    }
    [actions addObjectsFromArray:@[
      @{@"type": @"pointerMove", @"duration": @0, @"origin": element, @"x": @0, @"y": @0},
      @{@"type": @"pointerDown"},
      @{@"type": @"pause", @"duration": @100},
      @{@"type": @"pointerUp"},
      ]];
    return @{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": actions.copy,
      };
  };

  NSError *error;
  FBW3CActionsSynthesizer *baselineSynthesizer =
  [[FBW3CActionsSynthesizer alloc] initWithActions:@[sequenceWithLeadingPause(NO)]
                                     forApplication:self.testedApplication
                                       elementCache:nil
                                              error:&error];
  XCTAssertNotNil(baselineSynthesizer);
  XCSynthesizedEventRecord *baselineRecord = [baselineSynthesizer synthesizeWithError:&error];
  XCTAssertNotNil(baselineRecord, @"%@", error);

  FBW3CActionsSynthesizer *pausedSynthesizer =
  [[FBW3CActionsSynthesizer alloc] initWithActions:@[sequenceWithLeadingPause(YES)]
                                     forApplication:self.testedApplication
                                       elementCache:nil
                                              error:&error];
  XCTAssertNotNil(pausedSynthesizer);
  XCSynthesizedEventRecord *pausedRecord = [pausedSynthesizer synthesizeWithError:&error];
  XCTAssertNotNil(pausedRecord, @"%@", error);

  XCTAssertEqual(baselineRecord.eventPaths.count, (NSUInteger)1);
  XCTAssertEqual(pausedRecord.eventPaths.count, baselineRecord.eventPaths.count);

  XCPointerEventPath *baselinePath = baselineRecord.eventPaths.firstObject;
  XCPointerEventPath *pausedPath = pausedRecord.eventPaths.firstObject;
  XCTAssertEqual(pausedPath.pointerEvents.count, baselinePath.pointerEvents.count);
  for (NSUInteger i = 0; i < baselinePath.pointerEvents.count; i++) {
    XCPointerEvent *baselineEvent = baselinePath.pointerEvents[i];
    XCPointerEvent *pausedEvent = pausedPath.pointerEvents[i];
    XCTAssertEqual(pausedEvent.eventType, baselineEvent.eventType);
    XCTAssertEqualWithAccuracy(pausedEvent.offset, baselineEvent.offset, 0.001);
    XCTAssertEqualWithAccuracy(pausedEvent.coordinate.x, baselineEvent.coordinate.x, 0.001);
    XCTAssertEqualWithAccuracy(pausedEvent.coordinate.y, baselineEvent.coordinate.y, 0.001);
  }
}

- (void)testDoubleTap
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.testedApplication.buttons[FBShowAlertButtonName]},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @50},
          @{@"type": @"pointerUp"},
          @{@"type": @"pause", @"duration": @200},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @50},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyGesture:gesture orientation:UIDeviceOrientationLandscapeLeft];
}

- (void)testLongPressWithCombinedPause
{
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.testedApplication.buttons[FBShowAlertButtonName], @"x": @5, @"y": @5},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @200},
          @{@"type": @"pause", @"duration": @200},
          @{@"type": @"pause", @"duration": @100},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyGesture:gesture orientation:UIDeviceOrientationLandscapeRight];
}

- (void)testLongPress
{
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    XCTSkip(@"Failed on Azure Pipeline. Local run succeeded.");
  }
  UIDeviceOrientation orientation = UIDeviceOrientationLandscapeLeft;
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  CGRect elementFrame = self.testedApplication.buttons[FBShowAlertButtonName].frame;
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"x": @(elementFrame.origin.x + 1), @"y": @(elementFrame.origin.y + 1)},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @500},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyGesture:gesture orientation:orientation];
}

- (void)testForceTap
{
  if (![XCUIDevice.sharedDevice supportsPressureInteraction]) {
    XCTSkip(@"Device does not support pressure interaction");
  }

  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.testedApplication.buttons[FBShowAlertButtonName]},
          @{@"type": @"pointerDown"},
          @{@"type": @"pause", @"duration": @500},
          @{@"type": @"pointerDown", @"pressure": @1.0},
          @{@"type": @"pause", @"duration": @50},
          @{@"type": @"pointerDown", @"pressure": @1.0},
          @{@"type": @"pause", @"duration": @50},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyGesture:gesture orientation:UIDeviceOrientationLandscapeLeft];
}

@end


@implementation FBW3CTouchActionsIntegrationTestsPart2

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAttributesPage];
  });
  self.pickerWheel = self.testedApplication.pickerWheels.allElementsBoundByIndex.firstObject;
}

- (void)tearDown
{
  [self resetOrientation];
  [super tearDown];
}

- (void)verifyPickerWheelPositionChangeWithGesture:(NSArray<NSDictionary<NSString *, id> *> *)gesture
{
  NSString *previousValue = self.pickerWheel.value;
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performW3CActions:gesture elementCache:nil error:&error]);
  XCTAssertNil(error);
  XCTAssertTrue([[[[FBRunLoopSpinner new]
                   timeout:2.0]
                  timeoutErrorMessage:@"Picker wheel value has not been changed after 2 seconds timeout"]
                 spinUntilTrue:^BOOL{
    return ![[self.pickerWheel fb_standardSnapshot].value isEqualToString:previousValue];
                 }
                 error:&error]);
  XCTAssertNil(error);
}

- (void)testSwipePickerWheelWithElementCoordinates
{
  CGRect pickerFrame = self.pickerWheel.frame;
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"origin": self.pickerWheel, @"x": @0, @"y":@0},
          @{@"type": @"pointerDown"},
          @{@"type": @"pointerMove", @"duration": @500, @"origin": self.pickerWheel, @"x": @0, @"y": @(pickerFrame.size.height / 2)},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyPickerWheelPositionChangeWithGesture:gesture];
}

- (void)testSwipePickerWheelWithRelativeCoordinates
{
  CGRect pickerFrame = self.pickerWheel.frame;
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @250, @"origin": self.pickerWheel, @"x": @0, @"y": @0},
          @{@"type": @"pointerDown"},
          @{@"type": @"pointerMove", @"duration": @500, @"origin": @"pointer", @"x": @0, @"y": @(-pickerFrame.size.height / 2)},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyPickerWheelPositionChangeWithGesture:gesture];
}

- (void)testSwipePickerWheelWithAbsoluteCoordinates
{
  CGRect pickerFrame = self.pickerWheel.frame;
  NSArray<NSDictionary<NSString *, id> *> *gesture =
  @[@{
      @"type": @"pointer",
      @"id": @"finger1",
      @"parameters": @{@"pointerType": @"touch"},
      @"actions": @[
          @{@"type": @"pointerMove", @"duration": @0, @"x": @(pickerFrame.origin.x + pickerFrame.size.width / 2), @"y": @(pickerFrame.origin.y + pickerFrame.size.height / 2)},
          @{@"type": @"pointerDown"},
          @{@"type": @"pointerMove", @"duration": @500, @"origin": @"pointer", @"x": @0, @"y": @(pickerFrame.size.height / 2)},
          @{@"type": @"pointerUp"},
          ],
      },
    ];
  [self verifyPickerWheelPositionChangeWithGesture:gesture];
}

@end


