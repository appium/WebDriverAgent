/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NSArray<NSString *> *fb_accessibilityTraitsToStringsArray(unsigned long long traits) {
    NSMutableArray<NSString *> *traitStringsArray;
    NSString *traitString;
    NSNumber *key;
    
    static NSDictionary<NSNumber *, NSString *> *traitsMapping;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        traitsMapping = @{
            @(UIAccessibilityTraitNone): @"None",
            @(UIAccessibilityTraitButton): @"Button",
            @(UIAccessibilityTraitLink): @"Link",
            @(UIAccessibilityTraitHeader): @"Header",
            @(UIAccessibilityTraitSearchField): @"SearchField",
            @(UIAccessibilityTraitImage): @"Image",
            @(UIAccessibilityTraitSelected): @"Selected",
            @(UIAccessibilityTraitPlaysSound): @"PlaysSound",
            @(UIAccessibilityTraitKeyboardKey): @"KeyboardKey",
            @(UIAccessibilityTraitStaticText): @"StaticText",
            @(UIAccessibilityTraitSummaryElement): @"SummaryElement",
            @(UIAccessibilityTraitNotEnabled): @"NotEnabled",
            @(UIAccessibilityTraitUpdatesFrequently): @"UpdatesFrequently",
            @(UIAccessibilityTraitStartsMediaSession): @"StartsMediaSession",
            @(UIAccessibilityTraitAdjustable): @"Adjustable",
            @(UIAccessibilityTraitAllowsDirectInteraction): @"AllowsDirectInteraction",
            @(UIAccessibilityTraitCausesPageTurn): @"CausesPageTurn",
            @(UIAccessibilityTraitTabBar): @"TabBar",
            @(UIAccessibilityTraitToggleButton): @"ToggleButton",
            @(UIAccessibilityTraitSupportsZoom): @"SupportsZoom"
        };
    });

    traitStringsArray = [NSMutableArray array];
    for (key in traitsMapping) {
        if (traits & [key unsignedLongLongValue]) {
            traitString = traitsMapping[key];
            if (traitString != nil) {
                [traitStringsArray addObject:traitString];
            }
        }
    }

    return traitStringsArray;
}
