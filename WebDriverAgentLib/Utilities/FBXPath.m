/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXPath.h"

#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBXMLGenerationOptions.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "NSString+FBXMLSafeString.h"
#import "XCUIElement.h"
#import "XCUIElement+FBCaching.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCTestPrivateSymbols.h"


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

#if TARGET_OS_TV

@interface FBFocusedAttribute : FBElementAttribute

@end

#endif

const static char *_UTF8Encoding = "UTF-8";

static NSString *const kXMLIndexPathKey = @"private_indexPath";
static NSString *const topNodeIndexPath = @"top";

@implementation FBXPath

+ (id)throwException:(NSString *)name forQuery:(NSString *)xpathQuery
{
  NSString *reason = [NSString stringWithFormat:@"Cannot evaluate results for XPath expression \"%@\"", xpathQuery];
  @throw [NSException exceptionWithName:name reason:reason userInfo:@{}];
  return nil;
}

+ (nullable NSString *)xmlStringWithRootElement:(id<FBElement>)root
                                        options:(nullable FBXMLGenerationOptions *)options
{
  xmlDocPtr doc;
  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  int rc = xmlTextWriterStartDocument(writer, NULL, _UTF8Encoding, NULL);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartDocument. Error code: %d", rc];
  } else {
    BOOL hasScope = nil != options.scope && [options.scope length] > 0;
    if (hasScope) {
      rc = xmlTextWriterStartElement(writer,
                                     (xmlChar *)[[self safeXmlStringWithString:options.scope] UTF8String]);
      if (rc < 0) {
        [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartElement for the tag value '%@'. Error code: %d", options.scope, rc];
      }
    }

    if (rc >= 0) {
      rc = [self xmlRepresentationWithRootElement:root
                                           writer:writer
                                     elementStore:nil
                                            query:nil
                              excludingAttributes:options.excludedAttributes];
    }

    if (rc >= 0 && hasScope) {
      rc = xmlTextWriterEndElement(writer);
      if (rc < 0) {
        [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterEndElement. Error code: %d", rc];
      }
    }

    if (rc >= 0) {
      rc = xmlTextWriterEndDocument(writer);
      if (rc < 0) {
        [FBLogger logFmt:@"Failed to invoke libxml2>xmlXPathNewContext. Error code: %d", rc];
      }
    }
  }
  if (rc < 0) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    return nil;
  }
  int buffersize;
  xmlChar *xmlbuff;
  xmlDocDumpFormatMemory(doc, &xmlbuff, &buffersize, 1);
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);
  NSString *result = [NSString stringWithCString:(const char *)xmlbuff encoding:NSUTF8StringEncoding];
  xmlFree(xmlbuff);
  return result;
}

+ (NSArray<id<FBXCElementSnapshot>> *)matchesWithRootElement:(id<FBElement>)root
                                                    forQuery:(NSString *)xpathQuery
{
  xmlDocPtr doc;

  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  if (NULL == writer) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlNewTextWriterDoc for XPath query \"%@\"", xpathQuery];
    return [self throwException:FBXPathQueryEvaluationException forQuery:xpathQuery];
  }
  NSMutableDictionary *elementStore = [NSMutableDictionary dictionary];
  int rc = xmlTextWriterStartDocument(writer, NULL, _UTF8Encoding, NULL);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartDocument. Error code: %d", rc];
  } else {
    rc = [self xmlRepresentationWithRootElement:root
                                         writer:writer
                                   elementStore:elementStore
                                          query:xpathQuery
                            excludingAttributes:nil];
    if (rc >= 0) {
      rc = xmlTextWriterEndDocument(writer);
      if (rc < 0) {
        [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterEndDocument. Error code: %d", rc];
      }
    }
  }
  if (rc < 0) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    return [self throwException:FBXPathQueryEvaluationException forQuery:xpathQuery];
  }

  xmlXPathObjectPtr queryResult = [self evaluate:xpathQuery document:doc];
  if (NULL == queryResult) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    return [self throwException:FBInvalidXPathException forQuery:xpathQuery];
  }

  NSArray *matchingSnapshots = [self collectMatchingSnapshots:queryResult->nodesetval
                                                 elementStore:elementStore];
  xmlXPathFreeObject(queryResult);
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);
  if (nil == matchingSnapshots) {
    return [self throwException:FBXPathQueryEvaluationException forQuery:xpathQuery];
  }
  return matchingSnapshots;
}

+ (NSArray *)collectMatchingSnapshots:(xmlNodeSetPtr)nodeSet
                         elementStore:(NSMutableDictionary *)elementStore
{
  if (xmlXPathNodeSetIsEmpty(nodeSet)) {
    return @[];
  }
  NSMutableArray *matchingSnapshots = [NSMutableArray array];
  const xmlChar *indexPathKeyName = (xmlChar *)[kXMLIndexPathKey UTF8String];
  for (NSInteger i = 0; i < nodeSet->nodeNr; i++) {
    xmlNodePtr currentNode = nodeSet->nodeTab[i];
    xmlChar *attrValue = xmlGetProp(currentNode, indexPathKeyName);
    if (NULL == attrValue) {
      [FBLogger log:@"Failed to invoke libxml2>xmlGetProp"];
      return nil;
    }
    id<FBXCElementSnapshot> element = [elementStore objectForKey:(id)[NSString stringWithCString:(const char *)attrValue encoding:NSUTF8StringEncoding]];
    if (element) {
      [matchingSnapshots addObject:element];
    }
    xmlFree(attrValue);
  }
  return matchingSnapshots.copy;
}

+ (NSSet<Class> *)elementAttributesWithXPathQuery:(NSString *)query
{
  if ([query rangeOfString:@"[^\\w@]@\\*[^\\w]" options:NSRegularExpressionSearch].location != NSNotFound) {
    // read all element attributes if 'star' attribute name pattern is used in xpath query
    return [NSSet setWithArray:FBElementAttribute.supportedAttributes];
  }
  NSMutableSet<Class> *result = [NSMutableSet set];
  for (Class attributeCls in FBElementAttribute.supportedAttributes) {
    if ([query rangeOfString:[NSString stringWithFormat:@"[^\\w@]@%@[^\\w]", [attributeCls name]] options:NSRegularExpressionSearch].location != NSNotFound) {
      [result addObject:attributeCls];
    }
  }
  return result.copy;
}

+ (int)xmlRepresentationWithRootElement:(id<FBElement>)root
                                 writer:(xmlTextWriterPtr)writer
                           elementStore:(nullable NSMutableDictionary *)elementStore
                                  query:(nullable NSString*)query
                    excludingAttributes:(nullable NSArray<NSString *> *)excludedAttributes
{
  // Trying to be smart here and only including attributes, that were asked in the query, to the resulting document.
  // This may speed up the lookup significantly in some cases
  NSMutableSet<Class> *includedAttributes;
  if (nil == query) {
    includedAttributes = [NSMutableSet setWithArray:FBElementAttribute.supportedAttributes];
    // The hittable attribute is expensive to calculate for each snapshot item
    // thus we only include it when requested by an xPath query
    [includedAttributes removeObject:FBHittableAttribute.class];
    if (nil != excludedAttributes) {
      for (NSString *excludedAttributeName in excludedAttributes) {
        for (Class supportedAttribute in FBElementAttribute.supportedAttributes) {
          if ([[supportedAttribute name] caseInsensitiveCompare:excludedAttributeName] == NSOrderedSame) {
            [includedAttributes removeObject:supportedAttribute];
            break;
          }
        }
      }
    }
  } else {
    includedAttributes = [self.class elementAttributesWithXPathQuery:query].mutableCopy;
  }
  [FBLogger logFmt:@"The following attributes were requested to be included into the XML: %@", includedAttributes];

  int rc = [self writeXmlWithRootElement:root
                               indexPath:(elementStore != nil ? topNodeIndexPath : nil)
                            elementStore:elementStore
                      includedAttributes:includedAttributes.copy
                                  writer:writer];
  if (rc < 0) {
    [FBLogger log:@"Failed to generate XML presentation of a screen element"];
    return rc;
  }
  return 0;
}

+ (xmlXPathObjectPtr)evaluate:(NSString *)xpathQuery document:(xmlDocPtr)doc
{
  xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);
  if (NULL == xpathCtx) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlXPathNewContext for XPath query \"%@\"", xpathQuery];
    return NULL;
  }
  xpathCtx->node = doc->children;

  xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression((const xmlChar *)[xpathQuery UTF8String], xpathCtx);
  if (NULL == xpathObj) {
    xmlXPathFreeContext(xpathCtx);
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlXPathEvalExpression for XPath query \"%@\"", xpathQuery];
    return NULL;
  }
  xmlXPathFreeContext(xpathCtx);
  return xpathObj;
}

+ (nullable NSString *)safeXmlStringWithString:(NSString *)str
{
  return [str fb_xmlSafeStringWithReplacement:@""];
}

+ (int)recordElementAttributes:(xmlTextWriterPtr)writer
                    forElement:(id<FBXCElementSnapshot>)element
                     indexPath:(nullable NSString *)indexPath
            includedAttributes:(nullable NSSet<Class> *)includedAttributes
{
  for (Class attributeCls in FBElementAttribute.supportedAttributes) {
    // include all supported attributes by default unless enumerated explicitly
    if (includedAttributes && ![includedAttributes containsObject:attributeCls]) {
      continue;
    }
    int rc = [attributeCls recordWithWriter:writer
                                 forElement:[FBXCElementSnapshotWrapper ensureWrapped:element]];
    if (rc < 0) {
      return rc;
    }
  }

  if (nil != indexPath) {
    // index path is the special case
    return [FBInternalIndexAttribute recordWithWriter:writer forValue:indexPath];
  }
  return 0;
}

+ (int)writeXmlWithRootElement:(id<FBElement>)root
                     indexPath:(nullable NSString *)indexPath
                  elementStore:(nullable NSMutableDictionary *)elementStore
            includedAttributes:(nullable NSSet<Class> *)includedAttributes
                        writer:(xmlTextWriterPtr)writer
{
  NSAssert((indexPath == nil && elementStore == nil) || (indexPath != nil && elementStore != nil), @"Either both or none of indexPath and elementStore arguments should be equal to nil", nil);

  id<FBXCElementSnapshot> currentSnapshot;
  NSArray<id<FBXCElementSnapshot>> *children;
  if ([root isKindOfClass:XCUIElement.class]) {
    XCUIElement *element = (XCUIElement *)root;
    NSMutableArray<NSString *> *snapshotAttributes = [NSMutableArray arrayWithArray:FBStandardAttributeNames()];
    if (nil == includedAttributes || [includedAttributes containsObject:FBVisibleAttribute.class]) {
      [snapshotAttributes addObject:FB_XCAXAIsVisibleAttributeName];
      // If the app is not idle state while we retrieve the visiblity state
      // then the snapshot retrieval operation might freeze and time out
      [element.application fb_waitUntilStableWithTimeout:FBConfiguration.animationCoolOffTimeout];
    }
    currentSnapshot = [element fb_snapshotWithAttributes:snapshotAttributes.copy
                                                maxDepth:nil];
    children = currentSnapshot.children;
  } else {
    currentSnapshot = (id<FBXCElementSnapshot>)root;
    children = currentSnapshot.children;
  }

  if (elementStore != nil && indexPath != nil && [indexPath isEqualToString:topNodeIndexPath]) {
    [elementStore setObject:currentSnapshot forKey:topNodeIndexPath];
  }

  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:currentSnapshot];
  int rc = xmlTextWriterStartElement(writer, (xmlChar *)[wrappedSnapshot.wdType UTF8String]);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartElement for the tag value '%@'. Error code: %d", wrappedSnapshot.wdType, rc];
    return rc;
  }

  rc = [self recordElementAttributes:writer
                          forElement:currentSnapshot
                           indexPath:indexPath
                  includedAttributes:includedAttributes];
  if (rc < 0) {
    return rc;
  }

  for (NSUInteger i = 0; i < [children count]; i++) {
    id<FBXCElementSnapshot> childSnapshot = [children objectAtIndex:i];
    NSString *newIndexPath = (indexPath != nil) ? [indexPath stringByAppendingFormat:@",%lu", (unsigned long)i] : nil;
    if (elementStore != nil && newIndexPath != nil) {
      [elementStore setObject:childSnapshot forKey:(id)newIndexPath];
    }
    rc = [self writeXmlWithRootElement:[FBXCElementSnapshotWrapper ensureWrapped:childSnapshot]
                             indexPath:newIndexPath
                          elementStore:elementStore
                    includedAttributes:includedAttributes
                                writer:writer];
    if (rc < 0) {
      return rc;
    }
  }

  rc = xmlTextWriterEndElement(writer);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterEndElement. Error code: %d", rc];
    return rc;
  }
  return 0;
}

@end


static NSString *const FBAbstractMethodInvocationException = @"AbstractMethodInvocationException";

@implementation FBElementAttribute

- (instancetype)initWithElement:(id<FBElement>)element
{
  self = [super init];
  if (self) {
    _element = element;
  }
  return self;
}

+ (NSString *)name
{
  NSString *errMsg = [NSString stringWithFormat:@"The abstract method +(NSString *)name is expected to be overriden by %@", NSStringFromClass(self.class)];
  @throw [NSException exceptionWithName:FBAbstractMethodInvocationException reason:errMsg userInfo:nil];
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  NSString *errMsg = [NSString stringWithFormat:@"The abstract method -(NSString *)value is expected to be overriden by %@", NSStringFromClass(self.class)];
  @throw [NSException exceptionWithName:FBAbstractMethodInvocationException reason:errMsg userInfo:nil];
}

+ (int)recordWithWriter:(xmlTextWriterPtr)writer forElement:(id<FBElement>)element
{
  NSString *value = [self valueForElement:element];
  if (nil == value) {
    // Skip the attribute if the value equals to nil
    return 0;
  }
  int rc = xmlTextWriterWriteAttribute(writer,
                                       (xmlChar *)[[FBXPath safeXmlStringWithString:[self name]] UTF8String],
                                       (xmlChar *)[[FBXPath safeXmlStringWithString:value] UTF8String]);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterWriteAttribute(%@='%@'). Error code: %d", [self name], value, rc];
  }
  return rc;
}

+ (NSArray<Class> *)supportedAttributes
{
  // The list of attributes to be written for each XML node
  // The enumeration order does matter here
  return @[FBTypeAttribute.class,
           FBValueAttribute.class,
           FBNameAttribute.class,
           FBLabelAttribute.class,
           FBEnabledAttribute.class,
           FBVisibleAttribute.class,
           FBAccessibleAttribute.class,
#if TARGET_OS_TV
           FBFocusedAttribute.class,
#endif
           FBXAttribute.class,
           FBYAttribute.class,
           FBWidthAttribute.class,
           FBHeightAttribute.class,
           FBIndexAttribute.class,
           FBHittableAttribute.class,
          ];
}

@end

@implementation FBTypeAttribute

+ (NSString *)name
{
  return @"type";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return element.wdType;
}

@end

@implementation FBValueAttribute

+ (NSString *)name
{
  return @"value";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  id idValue = element.wdValue;
  if ([idValue isKindOfClass:[NSValue class]]) {
    return [idValue stringValue];
  } else if ([idValue isKindOfClass:[NSString class]]) {
    return idValue;
  }
  return [idValue description];
}

@end

@implementation FBNameAttribute

+ (NSString *)name
{
  return @"name";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return element.wdName;
}

@end

@implementation FBLabelAttribute

+ (NSString *)name
{
  return @"label";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return element.wdLabel;
}

@end

@implementation FBEnabledAttribute

+ (NSString *)name
{
  return @"enabled";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return FBBoolToString(element.wdEnabled);
}

@end

@implementation FBVisibleAttribute

+ (NSString *)name
{
  return @"visible";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return FBBoolToString(element.wdVisible);
}

@end

@implementation FBAccessibleAttribute

+ (NSString *)name
{
  return @"accessible";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return FBBoolToString(element.wdAccessible);
}

@end

#if TARGET_OS_TV

@implementation FBFocusedAttribute

+ (NSString *)name
{
  return @"focused";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return FBBoolToString(element.wdFocused);
}

@end

#endif

@implementation FBDimensionAttribute

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return [NSString stringWithFormat:@"%@", [element.wdRect objectForKey:[self name]]];
}

@end

@implementation FBXAttribute

+ (NSString *)name
{
  return @"x";
}

@end

@implementation FBYAttribute

+ (NSString *)name
{
  return @"y";
}

@end

@implementation FBWidthAttribute

+ (NSString *)name
{
  return @"width";
}

@end

@implementation FBHeightAttribute

+ (NSString *)name
{
  return @"height";
}

@end

@implementation FBIndexAttribute

+ (NSString *)name
{
  return @"index";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return [NSString stringWithFormat:@"%lu", element.wdIndex];
}

@end

@implementation FBHittableAttribute

+ (NSString *)name
{
  return @"hittable";
}

+ (NSString *)valueForElement:(id<FBElement>)element
{
  return FBBoolToString(element.wdHittable);
}

@end

@implementation FBInternalIndexAttribute

+ (NSString *)name
{
  return kXMLIndexPathKey;
}

+ (int)recordWithWriter:(xmlTextWriterPtr)writer forValue:(NSString *)value
{
  if (nil == value) {
    // Skip the attribute if the value equals to nil
    return 0;
  }
  int rc = xmlTextWriterWriteAttribute(writer,
                                       (xmlChar *)[[FBXPath safeXmlStringWithString:[self name]] UTF8String],
                                       (xmlChar *)[[FBXPath safeXmlStringWithString:value] UTF8String]);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterWriteAttribute(%@='%@'). Error code: %d", [self name], value, rc];
  }
  return rc;
}
@end
