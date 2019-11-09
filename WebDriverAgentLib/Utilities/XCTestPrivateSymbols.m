/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCTestPrivateSymbols.h"

#import <objc/runtime.h>

#import "FBRuntimeUtils.h"
#import "FBXCodeCompatibility.h"

NSNumber *FB_XCAXAIsVisibleAttribute;
NSString *FB_XCAXAIsVisibleAttributeName = @"XC_kAXXCAttributeIsVisible";
NSNumber *FB_XCAXAIsElementAttribute;
NSString *FB_XCAXAIsElementAttributeName = @"XC_kAXXCAttributeIsElement";

NSString *FB_IdentifierAttributeName = @"identifier";
NSString *FB_ValueAttributeName = @"value";
NSString *FB_FrameAttributeName = @"frame";
NSString *FB_LabelAttributeName = @"label";
NSString *FB_TitleAttributeName = @"title";
NSString *FB_EnabledAttributeName = @"enabled";
NSString *FB_SelectedAttributeName = @"selected";
NSString *FB_PlaceholderValueAttributeName = @"placeholderValue";
NSString *FB_HasFocusAttributeName = @"hasFocus";
NSString *FB_ElementTypeAttributeName = @"elementType";

void (*XCSetDebugLogger)(id <XCDebugLogDelegate>);
id<XCDebugLogDelegate> (*XCDebugLogger)(void);

NSArray<NSNumber *> *(*XCAXAccessibilityAttributesForStringAttributes)(id);

__attribute__((constructor)) void FBLoadXCTestSymbols(void)
{
  NSString *XC_kAXXCAttributeIsVisible = *(NSString*__autoreleasing*)FBRetrieveXCTestSymbol([FB_XCAXAIsVisibleAttributeName UTF8String]);
  NSString *XC_kAXXCAttributeIsElement = *(NSString*__autoreleasing*)FBRetrieveXCTestSymbol([FB_XCAXAIsElementAttributeName UTF8String]);

  XCAXAccessibilityAttributesForStringAttributes =
  (NSArray<NSNumber *> *(*)(id))FBRetrieveXCTestSymbol("XCAXAccessibilityAttributesForStringAttributes");

  XCSetDebugLogger = (void (*)(id <XCDebugLogDelegate>))FBRetrieveXCTestSymbol("XCSetDebugLogger");
  XCDebugLogger = (id<XCDebugLogDelegate>(*)(void))FBRetrieveXCTestSymbol("XCDebugLogger");

  NSArray<NSNumber *> *accessibilityAttributes = XCAXAccessibilityAttributesForStringAttributes(@[XC_kAXXCAttributeIsVisible, XC_kAXXCAttributeIsElement]);
  FB_XCAXAIsVisibleAttribute = accessibilityAttributes[0];
  FB_XCAXAIsElementAttribute = accessibilityAttributes[1];

  NSCAssert(FB_XCAXAIsVisibleAttribute != nil , @"Failed to retrieve FB_XCAXAIsVisibleAttribute", FB_XCAXAIsVisibleAttribute);
  NSCAssert(FB_XCAXAIsElementAttribute != nil , @"Failed to retrieve FB_XCAXAIsElementAttribute", FB_XCAXAIsElementAttribute);
}

void *FBRetrieveXCTestSymbol(const char *name)
{
  Class XCTestClass = objc_lookUpClass("XCTestCase");
  NSCAssert(XCTestClass != nil, @"XCTest should be already linked", XCTestClass);
  NSString *XCTestBinary = [NSBundle bundleForClass:XCTestClass].executablePath;
  const char *binaryPath = XCTestBinary.UTF8String;
  NSCAssert(binaryPath != nil, @"XCTest binary path should not be nil", binaryPath);
  return FBRetrieveSymbolFromBinary(binaryPath, name);
}

NSSet<NSString*> *FBStandardAttributeNames(void)
{
  static NSSet<NSString *> *standardNames;
  static dispatch_once_t onceStandardAttributeNamesToken;
  dispatch_once(&onceStandardAttributeNamesToken, ^{
    standardNames = [NSSet setWithArray:@[
      FB_IdentifierAttributeName,
      FB_ValueAttributeName,
      FB_LabelAttributeName,
      FB_FrameAttributeName,
      FB_EnabledAttributeName,
      FB_SelectedAttributeName,
      FB_PlaceholderValueAttributeName,
#if TARGET_OS_TV
      FB_HasFocusAttributeName,
#endif
      FB_ElementTypeAttributeName
    ]];
  });
  return standardNames;
}

NSSet<NSString*> *FBCustomAttributeNames(void)
{
  static NSSet<NSString *> *customNames;
  static dispatch_once_t onceCustomAttributeNamesToken;
  dispatch_once(&onceCustomAttributeNamesToken, ^{
    customNames = [NSSet setWithArray:@[
      FB_XCAXAIsVisibleAttributeName,
      FB_XCAXAIsElementAttributeName
    ]];
  });
  return customNames;
}

NSArray *FBCreateAXAttributes(NSSet<NSString *> *attributeNames)
{
  NSMutableArray<NSString *> *standardAttributeNames = [NSMutableArray array];
  for (NSString *attributeName in attributeNames) {
    if ([FBStandardAttributeNames() containsObject:attributeName]) {
      [standardAttributeNames addObject:attributeName];
    }
  }

  NSSet *axAttributes = nil;
  BOOL useSdk11Api = XCUIElement.fb_isSdk11SnapshotApiSupported;
  if (standardAttributeNames.count > 0) {
    SEL attributesForElementSnapshotKeyPathsSelector = [XCElementSnapshot fb_attributesForElementSnapshotKeyPathsSelector];
    axAttributes = (nil == attributesForElementSnapshotKeyPathsSelector) ? nil
      : [XCElementSnapshot performSelector:attributesForElementSnapshotKeyPathsSelector
                                withObject:standardAttributeNames];
    if (axAttributes == nil) {
      NSString *reason = [NSString stringWithFormat:@"Couldn't build the accessbility representation for attributes %@", standardAttributeNames];
      @throw [NSException exceptionWithName:@"AttributesEmpty" reason:reason userInfo:nil];
    }
  } else {
    axAttributes = [NSSet set];
  }

  NSMutableArray* result = useSdk11Api
    ? [NSMutableArray arrayWithArray:axAttributes.allObjects]
    : [NSMutableArray arrayWithArray:XCAXAccessibilityAttributesForStringAttributes(axAttributes)];
  for (NSString *attributeName in attributeNames) {
    if ([FB_XCAXAIsVisibleAttributeName isEqualToString:attributeName]) {
      [result addObject:(useSdk11Api ? attributeName : FB_XCAXAIsVisibleAttribute)];
    } else if ([FB_XCAXAIsElementAttributeName isEqualToString:attributeName]) {
      [result addObject:(useSdk11Api ? attributeName : FB_XCAXAIsElementAttribute)];
    }
  }
  return [result copy];
}
