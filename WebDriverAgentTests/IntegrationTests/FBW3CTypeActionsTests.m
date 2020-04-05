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
#import "XCUIElement+FBTyping.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBRuntimeUtils.h"
#import "FBXCodeCompatibility.h"


@interface FBW3CTypeActionsTests : FBIntegrationTestCase
@end

@implementation FBW3CTypeActionsTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
  [self goToAttributesPage];
}

- (void)testErroneousGestures
{
  if (![XCPointerEvent.class fb_areKeyEventsSupported]) {
    return;
  }

  NSArray<NSArray<NSDictionary<NSString *, id> *> *> *invalidGestures =
  @[

    // missing balance 1
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"keyDown", @"value": @"h"},
            @{@"type": @"keyUp", @"value": @"k"},
        ],
        },
      ],

    // missing balance 2
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"keyDown", @"value": @"h"},
        ],
        },
      ],

    // missing balance 3
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"keyUp", @"value": @"h"},
        ],
        },
      ],

    // missing key value
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"keyUp"},
        ],
        },
      ],

    // wrong key value
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"keyUp", @"value": @500},
        ],
        },
      ],

    // missing duration value
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"pause"},
        ],
        },
      ],

    // wrong duration value
    @[@{
        @"type": @"key",
        @"id": @"keyboard",
        @"actions": @[
            @{@"type": @"duration", @"duration": @"bla"},
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

- (void)testTextTyping
{
  if (![XCPointerEvent.class fb_areKeyEventsSupported]) {
    return;
  }

  XCUIElement *textField = self.testedApplication.textFields[@"aIdentifier"];
  [textField tap];
  NSArray<NSDictionary<NSString *, id> *> *typeAction =
    @[
      @{
      @"type": @"key",
      @"id": @"keyboard2",
      @"actions": @[
          @{@"type": @"pause", @"duration": @500},
          @{@"type": @"keyDown", @"value": @"🏀"},
          @{@"type": @"keyUp", @"value": @"🏀"},
          @{@"type": @"keyDown", @"value": @"N"},
          @{@"type": @"keyUp", @"value": @"N"},
          @{@"type": @"keyDown", @"value": @"B"},
          @{@"type": @"keyUp", @"value": @"B"},
          @{@"type": @"keyDown", @"value": @"a"},
          @{@"type": @"keyUp", @"value": @"a"},
          @{@"type": @"pause", @"duration": @500},
          ],
      },
      ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performW3CActions:typeAction
                                                elementCache:nil
                                                       error:&error]);
  XCTAssertNil(error);
  XCTAssertEqualObjects(textField.wdValue, @"🏀NBa");
}

@end
