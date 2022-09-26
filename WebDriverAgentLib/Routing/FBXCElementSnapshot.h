/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/CDStructures.h>

@protocol FBXCAccessibilityElement;

NS_ASSUME_NONNULL_BEGIN

@protocol FBXCElementSnapshot <NSObject, XCUIElementAttributes>

@property BOOL hasFocus; // @synthesize hasFocus=_hasFocus;
@property BOOL hasKeyboardFocus; // @synthesize hasKeyboardFocus=_hasKeyboardFocus;
@property(copy) NSDictionary *additionalAttributes; // @synthesize additionalAttributes=_additionalAttributes;
@property(copy) NSArray *userTestingAttributes; // @synthesize userTestingAttributes=_userTestingAttributes;
@property unsigned long long traits; // @synthesize traits=_traits;
@property BOOL isMainWindow; // @synthesize isMainWindow=_isMainWindow;
@property(copy) NSArray *children; // @synthesize children=_children;
@property id<FBXCElementSnapshot> parent; // @synthesize parent=_parent;
@property(retain) id<FBXCAccessibilityElement> parentAccessibilityElement; // @synthesize parentAccessibilityElement=_parentAccessibilityElement;
@property(retain) id<FBXCAccessibilityElement> accessibilityElement; // @synthesize accessibilityElement=_accessibilityElement;
@property(readonly) NSArray *suggestedHitpoints;
@property(readonly) struct CGRect visibleFrame;
@property(readonly) id<FBXCElementSnapshot> scrollView;
@property(readonly, copy) NSString *truncatedValueString;
@property(readonly) long long depth;
@property(readonly, copy) id<FBXCElementSnapshot> pathFromRoot;
@property(readonly) BOOL isTopLevelTouchBarElement;
@property(readonly) BOOL isTouchBarElement;
@property(readonly, copy) NSString *sparseTreeDescription;
@property(readonly, copy) NSString *compactDescription;
@property(readonly, copy) NSString *pathDescription;
@property(readonly) NSString *recursiveDescriptionIncludingAccessibilityElement;
@property(readonly) NSString *recursiveDescription;
@property(readonly, copy) NSArray *identifiers;
@property(nonatomic) unsigned long long generation; // @synthesize generation=_generation;
/*! DO NOT USE DIRECTLY! */
@property(nonatomic) XCUIApplication *application; // @synthesize application=_application;
/*! DO NOT USE DIRECTLY! */
@property(readonly) struct CGPoint hitPointForScrolling;
/*! DO NOT USE DIRECTLY! Please use fb_hitPoint instead */
@property(readonly) struct CGPoint hitPoint;

- (id)_uniquelyIdentifyingObjectiveCCode;
- (id)_uniquelyIdentifyingSwiftCode;
- (BOOL)_isAncestorOfElement:(id)arg1;
- (BOOL)_isDescendantOfElement:(id)arg1;
- (BOOL)_frameFuzzyMatchesElement:(id)arg1;
- (BOOL)_fuzzyMatchesElement:(id)arg1;
- (BOOL)_matchesElement:(id)arg1;
- (BOOL)matchesTreeWithRoot:(id)arg1;
- (void)mergeTreeWithSnapshot:(id)arg1;
- (id)_childMatchingElement:(id)arg1;
- (NSArray<id<FBXCElementSnapshot>> *)_allDescendants;
- (BOOL)hasDescendantMatchingFilter:(CDUnknownBlockType)arg1;
- (NSArray<id<FBXCElementSnapshot>> *)descendantsByFilteringWithBlock:(BOOL(^)(id<FBXCElementSnapshot> snapshot))block;
- (id)elementSnapshotMatchingAccessibilityElement:(id)arg1;
- (void)enumerateDescendantsUsingBlock:(void(^)(id<FBXCElementSnapshot> snapshot))block;
- (id)recursiveDescriptionWithIndent:(id)arg1 includeAccessibilityElement:(BOOL)arg2;
- (id)init;
- (struct CGPoint)hostingAndOrientationTransformedPoint:(struct CGPoint)arg1;
- (struct CGPoint)_transformPoint:(struct CGPoint)arg1 windowContextID:(id)arg2 windowDisplayID:(id)arg3;
- (id)hitTest:(struct CGPoint)arg1;

// Available since Xcode 10
- (id)hitPoint:(NSError **)error;

// Since Xcode 10.2
+ (id)axAttributesForElementSnapshotKeyPaths:(id)arg1 isMacOS:(_Bool)arg2;
// Since Xcode 10.0
+ (NSArray<NSString *> *)sanitizedElementSnapshotHierarchyAttributesForAttributes:(nullable NSArray<NSString *> *)arg1
                                                                          isMacOS:(_Bool)arg2;

@end

NS_ASSUME_NONNULL_END
