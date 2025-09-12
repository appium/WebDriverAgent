/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/FBElement.h>
#import <WebDriverAgentLib/FBXCElementSnapshot.h>

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"
#endif

#import <libxml/tree.h>
#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>
#import <libxml/encoding.h>
#import <libxml/xmlwriter.h>

#ifdef __clang__
#pragma clang diagnostic pop
#endif

@class FBXMLGenerationOptions;

NS_ASSUME_NONNULL_BEGIN

@interface FBXPath : NSObject

/**
 Returns an array of descendants matching given xpath query
 
 @param root the root element to execute XPath query for
 @param xpathQuery requested xpath query
 @return an array of descendants matching the given xpath query or an empty array if no matches were found
 @throws NSException if there is an unexpected internal error during xml parsing
 */
+ (NSArray<id<FBXCElementSnapshot>> *)matchesWithRootElement:(id<FBElement>)root
                                                    forQuery:(NSString *)xpathQuery;

/**
 Gets XML representation of XCElementSnapshot with all its descendants. This method generates the same
 representation, which is used for XPath search
 
 @param root the root element
 @param options Optional values that affect the resulting XML creation process
 @return valid XML document as string or nil in case of failure
 */
+ (nullable NSString *)xmlStringWithRootElement:(id<FBElement>)root
                                        options:(nullable FBXMLGenerationOptions *)options;

/**
    Exported by QAWolf
 */
+ (NSSet<Class> *)elementAttributesWithXPathQuery:(NSString *)query;


/**
    Exported by QAWolf
 */
+ (int)recordElementAttributes:(xmlTextWriterPtr)writer
                    forElement:(id<FBXCElementSnapshot>)element
                     indexPath:(nullable NSString *)indexPath
            includedAttributes:(nullable NSSet<Class> *)includedAttributes;

/**
    Exported by QAWolf
 */
+ (nullable NSString *)safeXmlStringWithString:(NSString *)str;

@end

/**
 These types were not being exported originally.
 */

@interface FBElementAttribute : NSObject

@property (nonatomic, readonly) id<FBElement> element;

+ (nonnull NSString *)name;
+ (nullable NSString *)valueForElement:(id<FBElement>)element;

+ (int)recordWithWriter:(xmlTextWriterPtr)writer forElement:(id<FBElement>)element;

+ (NSArray<Class> *)supportedAttributes;

@end

@interface FBTypeAttribute : FBElementAttribute

@end

@interface FBValueAttribute : FBElementAttribute

@end

@interface FBNameAttribute : FBElementAttribute

@end

@interface FBLabelAttribute : FBElementAttribute

@end

@interface FBEnabledAttribute : FBElementAttribute

@end

@interface FBVisibleAttribute : FBElementAttribute

@end

@interface FBAccessibleAttribute : FBElementAttribute

@end

@interface FBDimensionAttribute : FBElementAttribute

@end

@interface FBXAttribute : FBDimensionAttribute

@end

@interface FBYAttribute : FBDimensionAttribute

@end

@interface FBWidthAttribute : FBDimensionAttribute

@end

@interface FBHeightAttribute : FBDimensionAttribute

@end

@interface FBIndexAttribute : FBElementAttribute

@end

@interface FBHittableAttribute : FBElementAttribute

@end

@interface FBInternalIndexAttribute : FBElementAttribute

@property (nonatomic, nonnull, readonly) NSString* indexValue;

+ (int)recordWithWriter:(xmlTextWriterPtr)writer forValue:(NSString *)value;

@end

@interface FBPlaceholderValueAttribute : FBElementAttribute

@end

@interface FBNativeFrameAttribute : FBElementAttribute

@end

@interface FBTraitsAttribute : FBElementAttribute

@end

@interface FBMinValueAttribute : FBElementAttribute

@end

@interface FBMaxValueAttribute : FBElementAttribute

@end

#if TARGET_OS_TV

@interface FBFocusedAttribute : FBElementAttribute

@end

#endif

NS_ASSUME_NONNULL_END
