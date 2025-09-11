/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBAccessibilityTraits.h"

NSArray<NSString *> *FBAccessibilityTraitsToStringsArray(unsigned long long traits) {
    NSMutableArray<NSString *> *traitStringsArray;
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
        
        #if __clang_major__ >= 16
        // Add iOS 17.0 specific traits if available
        if (@available(iOS 17.0, *)) {
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
      if (traits & [key unsignedLongLongValue] && nil != traitsMapping[key]) {
        [traitStringsArray addObject:(id)traitsMapping[key]];
      }
    }

    return [traitStringsArray copy];
}
