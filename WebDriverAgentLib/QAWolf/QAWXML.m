//
//  XCUIElementSnapshot+XML.m
//  WebDriverAgent
//
//  Created by E. P. CARREIRO - SERVICOS DE INFORMATICA on 22/09/25.
//

#import <XCTest/XCTest.h>
#import "FBElement.h"
#import "QAWXML.h"
#import "FBXPath.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBXMLGenerationOptions.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIElement+FBWebDriverAttributes.h"


const static char *_UTF8Encoding = "UTF-8";

static NSString *const kXMLIndexPathKey = @"private_indexPath";
static NSString *const topNodeIndexPath = @"top";

@implementation QAWXML

+ (XMLRepresentationAndLeaves * _Nonnull)generateXMLStringAndLeaves:(SnapshotWithId * _Nonnull)root
                        withOptions:(nullable FBXMLGenerationOptions *)options
                        withMaxDepth:(int)maxDepth
                        parentLeafId:(nullable NSString *)parentLeafId;
{
  xmlDocPtr doc;
  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  int rc = xmlTextWriterStartDocument(writer, NULL, _UTF8Encoding, NULL);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartDocument. Error code: %d", rc];
    [QAWXML throwXMLErrorWithErrorCode:rc];
  }
  
  BOOL hasScope = nil != options.scope && [options.scope length] > 0;
  if (hasScope) {
    rc = xmlTextWriterStartElement(writer,
                                   (xmlChar *)[[FBXPath safeXmlStringWithString:options.scope] UTF8String]);
    if (rc < 0) {
      [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartElement for the tag value '%@'. Error code: %d", options.scope, rc];
      [QAWXML throwXMLErrorWithErrorCode:rc];
    }
  }

  NSMutableArray<SnapshotWithId *> *leaves = [NSMutableArray array];
  if (rc >= 0) {
    // If 'includeHittableInPageSource' setting is enabled, then use native snapshots
    // to calculate a more accurate value for the 'hittable' attribute.
    NSArray<SnapshotWithId *> * newLeaves = [self xmlRepresentationWithRootElement:root
                                         writer:writer
                                   elementStore:nil
                                          query:nil
                            excludingAttributes:options.excludedAttributes
                                       maxDepth:maxDepth
                                   parentLeafId:parentLeafId];
    
    [leaves addObjectsFromArray:newLeaves];
  }

  if (rc >= 0 && hasScope) {
    rc = xmlTextWriterEndElement(writer);
    if (rc < 0) {
      [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterEndElement. Error code: %d", rc];
      [QAWXML throwXMLErrorWithErrorCode:rc];
    }
  }

  if (rc >= 0) {
    rc = xmlTextWriterEndDocument(writer);
    if (rc < 0) {
      [FBLogger logFmt:@"Failed to invoke libxml2>xmlXPathNewContext. Error code: %d", rc];
      [QAWXML throwXMLErrorWithErrorCode:rc];
    }
  }
  
  if (rc < 0) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    [QAWXML throwXMLErrorWithErrorCode:rc];
  }
  
  int buffersize;
  xmlChar *xmlbuff;
  xmlDocDumpFormatMemory(doc, &xmlbuff, &buffersize, 1);
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);
  NSString *result = [NSString stringWithCString:(const char *)xmlbuff encoding:NSUTF8StringEncoding];
  xmlFree(xmlbuff);
  
  XMLWithParentId *xmlWithParentId = [XMLWithParentId initWithParentId:parentLeafId xmlString:result];
  XMLRepresentationAndLeaves *xmlRepresentationAndLeaves = [XMLRepresentationAndLeaves initWithXMLRepresentation:xmlWithParentId leaves:leaves];
  return xmlRepresentationAndLeaves;
}

+ (NSArray<SnapshotWithId *> * _Nonnull)xmlRepresentationWithRootElement:(SnapshotWithId *)root
                                 writer:(xmlTextWriterPtr)writer
                           elementStore:(nullable NSMutableDictionary *)elementStore
                                  query:(nullable NSString*)query
                    excludingAttributes:(nullable NSArray<NSString *> *)excludedAttributes
                               maxDepth:(int)maxDepth
                           parentLeafId:(nullable NSString *)parentLeafId;
{
  // Trying to be smart here and only including attributes, that were asked in the query, to the resulting document.
  // This may speed up the lookup significantly in some cases
  NSMutableSet<Class> *includedAttributes;
  if (nil == query) {
    includedAttributes = [NSMutableSet setWithArray:FBElementAttribute.supportedAttributes];
    if (!FBConfiguration.includeHittableInPageSource) {
      // The hittable attribute is expensive to calculate for each snapshot item
      // thus we only include it when requested explicitly
      [includedAttributes removeObject:FBHittableAttribute.class];
    }
    if (!FBConfiguration.includeNativeFrameInPageSource) {
      // Include nativeFrame only when requested
      [includedAttributes removeObject:FBNativeFrameAttribute.class];
    }
    if (!FBConfiguration.includeMinMaxValueInPageSource) {
      // minValue/maxValue are retrieved from private APIs and may be slow on deep trees
      [includedAttributes removeObject:FBMinValueAttribute.class];
      [includedAttributes removeObject:FBMaxValueAttribute.class];
    }
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

  return [self writeXmlWithRootElementSnapshot:root
                               indexPath:(elementStore != nil ? topNodeIndexPath : nil)
                            elementStore:elementStore
                      includedAttributes:includedAttributes.copy
                                  writer:writer
                                maxDepth:maxDepth
                            currentDepth:0
                            parentLeafId:parentLeafId];
}

+ (NSArray<SnapshotWithId *> * _Nonnull)writeXmlWithRootElementSnapshot:(SnapshotWithId *)root
                     indexPath:(nullable NSString *)indexPath
                  elementStore:(nullable NSMutableDictionary *)elementStore
            includedAttributes:(nullable NSSet<Class> *)includedAttributes
                        writer:(xmlTextWriterPtr)writer
                              maxDepth:(int)maxDepth
                          currentDepth:(int)currentDepth
                          parentLeafId:(nullable NSString *)parentLeafId;
{
  [FBLogger logFmt:@"Current depth: '%d'. Max depth: '%d'", currentDepth, maxDepth];
  NSAssert((indexPath == nil && elementStore == nil) || (indexPath != nil && elementStore != nil), @"Either both or none of indexPath and elementStore arguments should be equal to nil", nil);

  NSArray<id<FBXCElementSnapshot>> *children = root.snapshot.children;

  if (elementStore != nil && indexPath != nil && [indexPath isEqualToString:topNodeIndexPath]) {
    [elementStore setObject:root forKey:topNodeIndexPath];
  }

  FBXCElementSnapshotWrapper *wrappedSnapshot = [FBXCElementSnapshotWrapper ensureWrapped:root.snapshot];
  int rc = xmlTextWriterStartElement(writer, (xmlChar *)[wrappedSnapshot.wdType UTF8String]);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterStartElement for the tag value '%@'. Error code: %d", wrappedSnapshot.wdType, rc];
    [QAWXML throwXMLErrorWithErrorCode:rc];
  }

  NSMutableArray<SnapshotWithId *> *leaves = [NSMutableArray array];
  if (nil != parentLeafId && currentDepth == 0) {
    int rc = xmlTextWriterWriteAttribute(writer,
                                         (xmlChar *)[[FBXPath safeXmlStringWithString:@"parent-leaf-id"] UTF8String],
                                         (xmlChar *)[[FBXPath safeXmlStringWithString:parentLeafId] UTF8String]);
    
    if (rc < 0) {
      [FBLogger logFmt:@"Failed to write element parent-leaf-id. Error code: %d", rc];
      [QAWXML throwXMLErrorWithErrorCode:rc];
    }
  }
  
  rc = [FBXPath recordElementAttributes:writer
                          forElement:root.snapshot
                           indexPath:indexPath
                  includedAttributes:includedAttributes];
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to write element attributes. Error code: %d", rc];
    [QAWXML throwXMLErrorWithErrorCode:rc];
  }

  if (currentDepth == maxDepth) {
      int rc = xmlTextWriterWriteAttribute(writer,
                                           (xmlChar *)[[FBXPath safeXmlStringWithString:@"leaf-id"] UTF8String],
                                           (xmlChar *)[[FBXPath safeXmlStringWithString:root.id] UTF8String]);
      if (rc < 0) {
        [FBLogger logFmt:@"Failed to write element leaf-id. Error code: %d", rc];
        [QAWXML throwXMLErrorWithErrorCode:rc];
      }
    
    [leaves addObject:root];
  } else {
    for (NSUInteger i = 0; i < [children count]; i++) {
      @autoreleasepool {
        id<FBXCElementSnapshot> childSnapshot = [children objectAtIndex:i];
        NSString *newIndexPath = (indexPath != nil) ? [indexPath stringByAppendingFormat:@",%lu", (unsigned long)i] : nil;
        if (elementStore != nil && newIndexPath != nil) {
          [elementStore setObject:childSnapshot forKey:(id)newIndexPath];
        }
          
        SnapshotWithId *childSnapshotElement = [SnapshotWithId wrap:childSnapshot];
        
        NSArray<SnapshotWithId *> *newLeaves = [self writeXmlWithRootElementSnapshot:childSnapshotElement
                               indexPath:newIndexPath
                            elementStore:elementStore
                      includedAttributes:includedAttributes
                                  writer:writer
                                maxDepth:maxDepth
                            currentDepth:currentDepth + 1
                            parentLeafId:parentLeafId];
        
        [leaves addObjectsFromArray:newLeaves];
      }
    }
  }

  rc = xmlTextWriterEndElement(writer);
  if (rc < 0) {
    [FBLogger logFmt:@"Failed to invoke libxml2>xmlTextWriterEndElement. Error code: %d", rc];
    [QAWXML throwXMLErrorWithErrorCode:@(rc)];
  }
  
  return [leaves copy];
}

+ throwXMLErrorWithErrorCode:(int)rc {
  @throw [NSException exceptionWithName:@"XMLErrorException" reason:[NSString stringWithFormat:@"Got XML error code %d", rc] userInfo: @{NSLocalizedDescriptionKey: @"XML Error"}];
}

@end

@implementation SnapshotWithId

- (instancetype)initWithSnapshot:(id<FBXCElementSnapshot> _Nonnull)snapshot
            withId:(NSString *) id{
    self = [super init];
    if (self) {
        _snapshot = snapshot;
        _id = id;
    }
                
    return self;
}

+ (instancetype) wrap:(id<FBXCElementSnapshot> _Nonnull)snapshot {
    return [[self alloc] initWithSnapshot:snapshot withId:[[NSUUID UUID] UUIDString]];
}

@end

@implementation XMLWithParentId

- (instancetype)init:(NSString *)parentId xmlString:(NSString *)xmlString {
  self = [super init];
  if (self) {
      _parentId = parentId;
      _xmlString = xmlString;
  }
  return self;
}

+ (instancetype)initWithParentId:(NSString *)parentId xmlString:(NSString *)xmlString {
  return [[self alloc] init:parentId xmlString:xmlString];
}

@end


@implementation XMLRepresentationAndLeaves
  

- (instancetype)init:(XMLWithParentId *)xml leaves:(NSArray<SnapshotWithId *> *)leaves {
  self = [super init];
  if (self) {
      _xml = xml;
      _leaves = leaves;
  }
  return self;
}


+ (instancetype)initWithXMLRepresentation:(XMLWithParentId *)xml leaves:(NSArray<SnapshotWithId *> *)leaves {
  return [[self alloc] init:xml leaves:leaves];
}

@end


