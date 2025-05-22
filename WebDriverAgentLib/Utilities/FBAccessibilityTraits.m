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
        NSMutableDictionary<NSNumber *, NSString *> *mapping = [@{
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
            @(UIAccessibilityTraitTabBar): @"TabBar"
        } mutableCopy];
        
        // Add iOS 17.0 and watchOS 10.0 specific traits if available
        #if TARGET_OS_IOS
        if (@available(iOS 17.0, *)) {
            [mapping addEntriesFromDictionary:@{
                @(UIAccessibilityTraitToggleButton): @"ToggleButton",
                @(UIAccessibilityTraitSupportsZoom): @"SupportsZoom"
            }];
        }
        #elif TARGET_OS_WATCH
        if (@available(watchOS 10.0, *)) {
            [mapping addEntriesFromDictionary:@{
                @(UIAccessibilityTraitToggleButton): @"ToggleButton",
                @(UIAccessibilityTraitSupportsZoom): @"SupportsZoom"
            }];
        }
        #endif
        
        traitsMapping = [mapping copy];
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
