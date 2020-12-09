/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@protocol XCDebugLogDelegate;

/*! Accessibility identifier for is visible attribute */
extern NSNumber *FB_XCAXAIsVisibleAttribute;
extern NSString *FB_XCAXAIsVisibleAttributeName;

/*! Accessibility identifier for is accessible attribute */
extern NSNumber *FB_XCAXAIsElementAttribute;
extern NSString *FB_XCAXAIsElementAttributeName;

/*! Getter for  XCTest logger */
extern id<XCDebugLogDelegate> (*XCDebugLogger)(void);

/*! Setter for  XCTest logger */
extern void (*XCSetDebugLogger)(id <XCDebugLogDelegate>);

/*! Maps string attributes to AX Accesibility Attributes*/
extern NSArray<NSNumber *> *(*XCAXAccessibilityAttributesForStringAttributes)(id stringAttributes);

/**
 Method used to retrieve pointer for given symbol 'name' from given 'binary'

 @param name name of the symbol
 @return pointer to symbol
 */
void *FBRetrieveXCTestSymbol(const char *name);

/*! Static constructor that will retrieve XCTest private symbols */
__attribute__((constructor)) void FBLoadXCTestSymbols(void);

/**
 Method is used to tranform attribute names into the format, which
 is acceptable for the internal XCTest snpshoting API

 @param attributeNames set of attribute names. Must be on of FB_..Name constants above
 @returns The array of tranformed values. Unknown values are silently skipped
 */
NSArray *FBCreateAXAttributes(NSSet<NSString *> *attributeNames);

/**
 Retrives the set of standard attribute names

 @returns Array of FB_..Name constants above, which represent standard element attributes
 */
NSArray<NSString*> *FBStandardAttributeNames(void);

/**
Retrives the set of custom attribute names. These attributes are normally not accessible
 by public XCTest calls, but are still available in the accessibility framework

@returns Array of FB_..Name constants above, which represent custom element attributes
*/
NSArray<NSString*> *FBCustomAttributeNames(void);
