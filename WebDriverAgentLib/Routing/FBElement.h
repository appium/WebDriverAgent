/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol that should be implemented by class that can return element properties defined in WebDriver Spec
 */
@protocol FBElement <NSObject>

/*! Element's frame in normalized (rounded dimensions without Infinity values) CGRect format */
@property (nonatomic, readonly, assign) CGRect wdFrame;

/*! Represents the element's frame as a CGRect, preserving the actual values. */
@property (nonatomic, readonly, assign) CGRect wdNativeFrame;

/*! Element's wsFrame in NSDictionary format */
@property (nonatomic, readonly, copy) NSDictionary *wdRect;

/*! Element's name */
@property (nonatomic, readonly, copy, nullable) NSString *wdName;

/*! Element's label */
@property (nonatomic, readonly, copy, nullable) NSString *wdLabel;

/*! Element's selected state */
@property (nonatomic, readonly, getter = isWDSelected) BOOL wdSelected;

/*! Element's type */
@property (nonatomic, readonly, copy) NSString *wdType;

/*! Element's accessibility traits as a comma-separated string */
@property (nonatomic, readonly, copy) NSString *wdTraits;

/*! Element's value */
@property (nonatomic, readonly, strong, nullable) NSString *wdValue;

/*! Element's unique identifier */
@property (nonatomic, readonly, copy, nullable) NSString *wdUID;

/*! Whether element is enabled */
@property (nonatomic, readonly, getter = isWDEnabled) BOOL wdEnabled;

/*! Whether element is visible */
@property (nonatomic, readonly, getter = isWDVisible) BOOL wdVisible;

/*! Whether element is accessible */
@property (nonatomic, readonly, getter = isWDAccessible) BOOL wdAccessible;

/*! Whether element is an accessibility container (contains children of any depth that are accessible) */
@property (nonatomic, readonly, getter = isWDAccessibilityContainer) BOOL wdAccessibilityContainer;

/*! Whether element is focused */
@property (nonatomic, readonly, getter = isWDFocused) BOOL wdFocused;

/*! Whether element is hittable */
@property (nonatomic, readonly, getter = isWDHittable) BOOL wdHittable;

/*! Element's index relatively to its parent. Starts from zero */
@property (nonatomic, readonly) NSUInteger wdIndex;

/*! Element's placeholder value */
@property (nonatomic, readonly, copy, nullable) NSString *wdPlaceholderValue;

/*! Element's minimum value */
@property (nonatomic, readonly, strong, nullable) NSNumber *wdMinValue;

/*! Element's maximum value */
@property (nonatomic, readonly, strong, nullable) NSNumber *wdMaxValue;

/**
 Returns value of given property specified in WebDriver Spec
 Check the FBElement protocol to get list of supported attributes.
 This method also supports shortcuts, like wdName == name, wdValue == value.
 
 @param name WebDriver Spec property name
 @return the corresponding property value
 @throws FBUnknownAttributeException if there is no matching attribute defined in FBElement protocol
 */
- (nullable id)fb_valueForWDAttributeName:(NSString *__nullable)name;

@end

NS_ASSUME_NONNULL_END
