/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <WebDriverAgentLib/FBXPath.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBXPath ()

/**
 Gets xmllib2-compatible XML representation of n XCElementSnapshot instance

 @param root The root element to generate XML from.
 @param writer The corresponding libxml2 writer object.
 @param elementStore An optional mutable dictionary used to store index path to snapshot mappings. Pass nil to skip mapping.
 @param query An optional XPath query string. If provided, it will be used to optimize the list of included attributes.
 @param options Optional configuration object that allows fine-tuning of the XML generation process.
                If `query` is provided, options.excludedAttributes and useNativeHittable will be ignored.
                If `query` is nil:
                  - `options.excludedAttributes` can be used to exclude specific XML attributes from the output.
                  - `options.useNativeHittable` enables the calculation of true `hittable` values using native snapshots (expensive).
  @return Zero if the method completes successfully, or a negative libxml2 error code otherwise.
  */
 + (int)xmlRepresentationWithRootElement:(id<FBXCElementSnapshot>)root
                                  writer:(xmlTextWriterPtr)writer
                            elementStore:(nullable NSMutableDictionary *)elementStore
                                   query:(nullable NSString*)query
                                 options:(nullable FBXMLGenerationOptions *)options;

/**
 Gets the list of matched snapshots from xmllib2-compatible xmlNodeSetPtr structure
 
 @param nodeSet set of nodes returned after successful XPath evaluation
 @param elementStore dictionary containing index->snapshot mapping
 @return array of filtered elements or nil in case of failure. Can be empty array as well
 */
+ (NSArray *)collectMatchingSnapshots:(xmlNodeSetPtr)nodeSet elementStore:(NSMutableDictionary *)elementStore;

/**
 Gets the list of matched XPath nodes from xmllib2-compatible XML document
 
 @param xpathQuery actual query. Should be valid XPath 1.0-compatible expression
 @param document libxml2-compatible document pointer
 @param contextNode Optonal context node instance
 @return pointer to a libxml2-compatible structure with set of matched nodes or NULL in case of failure
 */
+ (xmlXPathObjectPtr)evaluate:(NSString *)xpathQuery
                     document:(xmlDocPtr)doc
                  contextNode:(nullable xmlNodePtr)contextNode;

@end

NS_ASSUME_NONNULL_END
