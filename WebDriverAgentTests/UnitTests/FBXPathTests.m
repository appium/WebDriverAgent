/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBMacros.h"
#import "FBXPath.h"
#import "FBXPath-Private.h"
#import "XCUIElementDouble.h"
#import "XCElementSnapshotDouble.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"

@interface FBXPathTests : XCTestCase
@end

@implementation FBXPathTests

- (NSString *)xmlStringWithElement:(id<FBElement>)element
                        xpathQuery:(nullable NSString *)query
               excludingAttributes:(nullable NSArray<NSString *> *)excludedAttributes
{
  xmlDocPtr doc;
  
  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  NSMutableDictionary *elementStore = [NSMutableDictionary dictionary];
  int buffersize;
  xmlChar *xmlbuff = NULL;
  int rc = xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL);
  if (rc >= 0) {
    rc = [FBXPath xmlRepresentationWithRootElement:element
                                            writer:writer
                                      elementStore:elementStore
                                             query:query
                               excludingAttributes:excludedAttributes];
    if (rc >= 0) {
      rc = xmlTextWriterEndDocument(writer);
    }
  }
  if (rc >= 0) {
    xmlDocDumpFormatMemory(doc, &xmlbuff, &buffersize, 1);
  }
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);
  
  XCTAssertTrue(rc >= 0);
  XCTAssertEqual(1, [elementStore count]);

  NSString *result = [NSString stringWithCString:(const char *)xmlbuff encoding:NSUTF8StringEncoding];
  xmlFree(xmlbuff);
  return result;
}

- (void)testDefaultXPathPresentation
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:element
                                        xpathQuery:nil
                               excludingAttributes:nil];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" value=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdType, element.wdValue, element.wdName, element.wdLabel, FBBoolToString(element.wdEnabled), FBBoolToString(element.wdVisible), FBBoolToString(element.wdAccessible), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"], element.wdIndex];
  XCTAssertTrue([resultXml isEqualToString: expectedXml]);
}

- (void)testtXPathPresentationWithSomeAttributesExcluded
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:element
                                        xpathQuery:nil
                               excludingAttributes:@[@"type", @"visible", @"value", @"index"]];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ name=\"%@\" label=\"%@\" enabled=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdName, element.wdLabel, FBBoolToString(element.wdEnabled), FBBoolToString(element.wdAccessible), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"]];
  XCTAssertEqualObjects(resultXml, expectedXml);
}

- (void)testXPathPresentationBasedOnQueryMatchingAllAttributes
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  snapshot.value = @"йоло<>&\"";
  snapshot.label = @"a\nb";
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:element
                                        xpathQuery:[NSString stringWithFormat:@"//%@[@*]", element.wdType]
                               excludingAttributes:@[@"visible"]];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" value=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\" hittable=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdType, @"йоло&lt;&gt;&amp;&quot;", element.wdName, @"a&#10;b", FBBoolToString(element.wdEnabled), FBBoolToString(element.wdVisible), FBBoolToString(element.wdAccessible), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"], element.wdIndex, FBBoolToString(element.wdHittable)];
  XCTAssertEqualObjects(expectedXml, resultXml);
}

- (void)testXPathPresentationBasedOnQueryMatchingSomeAttributes
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:element
                                        xpathQuery:[NSString stringWithFormat:@"//%@[@%@ and contains(@%@, 'blabla')]", element.wdType, @"value", @"name"]
                               excludingAttributes:nil];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ value=\"%@\" name=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdValue, element.wdName];
  XCTAssertTrue([resultXml isEqualToString: expectedXml]);
}

- (void)testSnapshotXPathResultsMatching
{
  xmlDocPtr doc;

  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  NSMutableDictionary *elementStore = [NSMutableDictionary dictionary];
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> root = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *query = [NSString stringWithFormat:@"//%@", root.wdType];
  int rc = xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL);
  if (rc >= 0) {
    rc = [FBXPath xmlRepresentationWithRootElement:root
                                            writer:writer
                                      elementStore:elementStore
                                             query:query
                               excludingAttributes:nil];
    if (rc >= 0) {
      rc = xmlTextWriterEndDocument(writer);
    }
  }
  if (rc < 0) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    XCTFail(@"Unable to create the source XML document");
  }

  xmlXPathObjectPtr queryResult = [FBXPath evaluate:query document:doc];
  if (NULL == queryResult) {
    xmlFreeTextWriter(writer);
    xmlFreeDoc(doc);
    XCTAssertNotEqual(NULL, queryResult);
  }

  NSArray *matchingSnapshots = [FBXPath collectMatchingSnapshots:queryResult->nodesetval
                                                    elementStore:elementStore];
  xmlXPathFreeObject(queryResult);
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);

  XCTAssertNotNil(matchingSnapshots);
  XCTAssertEqual(1, [matchingSnapshots count]);
}

@end
