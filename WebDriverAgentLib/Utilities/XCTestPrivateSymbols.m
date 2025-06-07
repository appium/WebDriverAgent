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
NSString *FB_XCAXAVisibleFrameAttributeName = @"XC_kAXXCAttributeVisibleFrame";
NSNumber *FB_XCAXACustomMinValueAttribute;
NSString *FB_XCAXACustomMinValueAttributeName = @"XC_kAXXCAttributeMinValue";
NSNumber *FB_XCAXACustomMaxValueAttribute;
NSString *FB_XCAXACustomMaxValueAttributeName = @"XC_kAXXCAttributeMaxValue";

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
  
  NSString *XC_kAXXCAttributeMinValue = *(NSString *__autoreleasing *)FBRetrieveXCTestSymbol([FB_XCAXACustomMinValueAttributeName UTF8String]);
  NSString *XC_kAXXCAttributeMaxValue = *(NSString *__autoreleasing *)FBRetrieveXCTestSymbol([FB_XCAXACustomMaxValueAttributeName UTF8String]);
  
  NSArray<NSNumber *> *minMaxAttrs = XCAXAccessibilityAttributesForStringAttributes(@[XC_kAXXCAttributeMinValue, XC_kAXXCAttributeMaxValue]);
  FB_XCAXACustomMinValueAttribute = minMaxAttrs[0];
  FB_XCAXACustomMaxValueAttribute = minMaxAttrs[1];
  
  NSCAssert(FB_XCAXACustomMinValueAttribute != nil, @"Failed to retrieve FB_XCAXACustomMinValueAttribute", FB_XCAXACustomMinValueAttribute);
  NSCAssert(FB_XCAXACustomMaxValueAttribute != nil, @"Failed to retrieve FB_XCAXACustomMaxValueAttribute", FB_XCAXACustomMaxValueAttribute);
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

NSArray<NSString*> *FBStandardAttributeNames(void)
{
  static NSArray<NSString *> *attributeNames;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class xcElementSnapshotClass = NSClassFromString(@"XCElementSnapshot");
    NSCAssert(nil != xcElementSnapshotClass, @"XCElementSnapshot class must be resolvable", xcElementSnapshotClass);
    attributeNames = [xcElementSnapshotClass sanitizedElementSnapshotHierarchyAttributesForAttributes:nil
                                                                                              isMacOS:NO];
  });
  return attributeNames;
}

NSArray<NSString*> *FBCustomAttributeNames(void)
{
  static NSArray<NSString *> *customNames;
  static dispatch_once_t onceCustomAttributeNamesToken;
  dispatch_once(&onceCustomAttributeNamesToken, ^{
    customNames = @[
      FB_XCAXAIsVisibleAttributeName,
      FB_XCAXAIsElementAttributeName,
      FB_XCAXACustomMinValueAttributeName,
      FB_XCAXACustomMaxValueAttributeName
    ];
  });
  return customNames;
}
