/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"

#import "XCUIElement.h"
#import "XCUIApplication+FBTouchAction.h"
#import "FBTestMacros.h"
#import "XCUIDevice+FBRotation.h"
#import "FBRunLoopSpinner.h"

@interface FBAppiumMultiTouchActionsIntegrationTestsPart1 : FBIntegrationTestCase
@end

@interface FBAppiumMultiTouchActionsIntegrationTestsPart2 : FBIntegrationTestCase
@property (nonatomic) XCUIElement *touchesLabel;
@property (nonatomic) XCUIElement *tapsLabel;
@end

@implementation FBAppiumMultiTouchActionsIntegrationTestsPart1

- (void)verifyGesture:(NSArray<NSArray<NSDictionary<NSString *, id> *> *> *)gesture orientation:(UIDeviceOrientation)orientation
{
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performAppiumTouchActions:gesture elementCache:nil error:&error]);
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
    // One of the chains is empty
    @[
      @[],
      @[@{@"action": @"tap",
          @"options": @{
              @"ELEMENT": self.testedApplication.buttons[FBShowAlertButtonName],
              }
          }
      ],
    ],
    
  ];
  
  for (NSArray<NSArray<NSDictionary<NSString *, id> *> *> *invalidGesture in invalidGestures) {
    NSError *error;
    XCTAssertFalse([self.testedApplication fb_performAppiumTouchActions:invalidGesture elementCache:nil  error:&error]);
    XCTAssertNotNil(error);
  }
}

- (void)testSymmetricTwoFingersTap
{
  XCUIElement *element = self.testedApplication.buttons[FBShowAlertButtonName];
  NSArray<NSArray<NSDictionary<NSString *, id> *> *> *gesture =
  @[
    @[@{
      @"action": @"tap",
      @"options": @{
          @"ELEMENT": element
          }
      }
    ],
    @[@{
        @"action": @"tap",
        @"options": @{
            @"ELEMENT": element
            }
        }
    ],
  ];
  
  [self verifyGesture:gesture orientation:UIDeviceOrientationPortrait];
}

@end

@implementation FBAppiumMultiTouchActionsIntegrationTestsPart2

- (void)verifyGesture:(NSArray<NSArray<NSDictionary<NSString *, id> *>*>*)gesture orientation:(UIDeviceOrientation)orientation tapsCount:(int)tapsCount touchesCount:(int)touchesCount
{
  [[XCUIDevice sharedDevice] fb_setDeviceInterfaceOrientation:orientation];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performAppiumTouchActions:gesture elementCache:nil error:&error]);
  NSString *taps = [[self tapsLabel] label];
  NSString *touches = [[self touchesLabel] label] ;
  BOOL tapsEqual = [[NSString stringWithFormat:@"%d", tapsCount] isEqualToString:taps];
  BOOL touchesEqual = [[NSString stringWithFormat:@"%d", touchesCount] isEqualToString:touches];
  XCTAssertTrue(tapsEqual);
  XCTAssertTrue(touchesEqual);
}

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToTouchPage];
  });
  self.touchesLabel = self.testedApplication.staticTexts[FBTouchesCountLabelIdentifier];
  self.tapsLabel = self.testedApplication.staticTexts[FBTapsCountLabelIdentifier];
}

- (void)testMultiTouchWithMultiTaps
{
  XCUIElement *touchableView = self.testedApplication.otherElements[@"touchableView"];
  XCTAssertNotNil(touchableView);
  NSArray<NSArray<NSDictionary<NSString *, id> *>*> *gesture =
  @[@[@{
        @"action": @"tap",
        @"options": @{
            @"ELEMENT": touchableView
            }
        },
      @{
        @"action": @"wait",
        @"options": @{
            @"ms": @1000
            }
        },
      @{
        @"action": @"tap",
        @"options": @{
            @"ELEMENT": touchableView
            }
        },
      @{
        @"action": @"wait",
        @"options": @{
            @"ms": @1000
            }
        },
      @{
        @"action": @"release"
        }
      ],
      @[@{
        @"action": @"tap",
        @"options": @{
            @"ELEMENT": touchableView
            }
        },
      @{
        @"action": @"wait",
        @"options": @{
            @"ms": @1000
            }
        },
      @{
        @"action": @"tap",
        @"options": @{
            @"ELEMENT": touchableView
            }
        },
      @{
        @"action": @"wait",
        @"options": @{
            @"ms": @1000
            }
        },
      @{
        @"action": @"release"
        }
    ]
    
  ];
  [self verifyGesture:gesture orientation:UIDeviceOrientationPortrait tapsCount:2 touchesCount:2];
}

@end
