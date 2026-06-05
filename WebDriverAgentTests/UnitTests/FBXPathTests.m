/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBMacros.h"
#import "FBXPath.h"
#import "FBXPath-Private.h"
#import "XCUIElementDouble.h"
#import "XCElementSnapshotDouble.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCTestPrivateSymbols.h"

@interface FBXPathTests : XCTestCase
@end

@implementation FBXPathTests

- (NSString *)xmlStringWithElement:(id<FBXCElementSnapshot>)snapshot
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
    rc = [FBXPath xmlRepresentationWithRootElement:snapshot
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
  NSString *resultXml = [self xmlStringWithElement:(id<FBXCElementSnapshot>)element
                                        xpathQuery:nil
                               excludingAttributes:nil];
  NSLog(@"[DefaultXPath] Result XML:\n%@", resultXml);
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" value=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\" traits=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdType, element.wdValue, element.wdName, element.wdLabel, FBBoolToString(element.wdEnabled), FBBoolToString(element.wdVisible), FBBoolToString(element.wdAccessible), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"], element.wdIndex, element.wdTraits];
  XCTAssertTrue([resultXml isEqualToString: expectedXml]);
}

- (void)testXPathPresentationWithSomeAttributesExcluded
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:(id<FBXCElementSnapshot>)element
                                        xpathQuery:nil
                               excludingAttributes:@[@"type", @"visible", @"value", @"index", @"traits", @"nativeFrame"]];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ name=\"%@\" label=\"%@\" enabled=\"%@\" accessible=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdName, element.wdLabel, FBBoolToString(element.wdEnabled), FBBoolToString(element.wdAccessible), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"]];
  XCTAssertEqualObjects(resultXml, expectedXml);
}

- (void)testXPathPresentationBasedOnQueryMatchingAllAttributes
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  snapshot.value = @"йоло<>&\"";
  snapshot.label = @"a\nb";
  NSString *testCustomActions = @"Custom Action 1, Custom Action 2";
  snapshot.additionalAttributes[FB_XCAXACustomActionsAttribute] = testCustomActions;
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:(id<FBXCElementSnapshot>)element
                                        xpathQuery:[NSString stringWithFormat:@"//%@[@*]", element.wdType]
                               excludingAttributes:@[@"visible"]];
  NSString *expectedXml = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<%@ type=\"%@\" value=\"%@\" name=\"%@\" label=\"%@\" enabled=\"%@\" visible=\"%@\" accessible=\"%@\" nativeAccessibilityElement=\"%@\" x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" index=\"%lu\" hittable=\"%@\" traits=\"%@\" nativeFrame=\"%@\" customActions=\"%@\" private_indexPath=\"top\"/>\n",
                           element.wdType, element.wdType, @"йоло&lt;&gt;&amp;&quot;", element.wdName, @"a&#10;b", FBBoolToString(element.wdEnabled), FBBoolToString(element.wdVisible), FBBoolToString(element.wdAccessible), FBBoolToString(element.wdNativeAccessibilityElement), element.wdRect[@"x"], element.wdRect[@"y"], element.wdRect[@"width"], element.wdRect[@"height"], element.wdIndex, FBBoolToString(element.wdHittable), element.wdTraits, NSStringFromCGRect(element.wdNativeFrame), element.wdCustomActions];
  XCTAssertEqualObjects(expectedXml, resultXml);
}

- (void)testXPathPresentationBasedOnQueryMatchingSomeAttributes
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  id<FBElement> element = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  NSString *resultXml = [self xmlStringWithElement:(id<FBXCElementSnapshot>)element
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
    rc = [FBXPath xmlRepresentationWithRootElement:(id<FBXCElementSnapshot>)root
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

  xmlXPathObjectPtr queryResult = [FBXPath evaluate:query document:doc contextNode:NULL];
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

- (NSString *)xpathStringResultForQuery:(NSString *)query document:(xmlDocPtr)doc
{
  xmlXPathObjectPtr queryResult = [FBXPath evaluate:query document:doc contextNode:NULL];
  if (NULL == queryResult) {
    return nil;
  }
  xmlChar *stringValue = xmlXPathCastToString(queryResult);
  xmlXPathFreeObject(queryResult);
  if (NULL == stringValue) {
    return nil;
  }
  NSString *result = [NSString stringWithUTF8String:(const char *)stringValue];
  xmlFree(stringValue);
  return result;
}

- (BOOL)xpathBooleanResultForQuery:(NSString *)query document:(xmlDocPtr)doc
{
  xmlXPathObjectPtr queryResult = [FBXPath evaluate:query document:doc contextNode:NULL];
  if (NULL == queryResult) {
    return NO;
  }
  BOOL result = queryResult->boolval;
  xmlXPathFreeObject(queryResult);
  return result;
}

- (xmlDocPtr)documentForSnapshot:(XCElementSnapshotDouble *)snapshot query:(NSString *)query
{
  xmlDocPtr doc;
  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  NSMutableDictionary *elementStore = [NSMutableDictionary dictionary];
  id<FBElement> root = (id<FBElement>)[FBXCElementSnapshotWrapper ensureWrapped:(id)snapshot];
  int rc = xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL);
  if (rc >= 0) {
    rc = [FBXPath xmlRepresentationWithRootElement:(id<FBXCElementSnapshot>)root
                                            writer:writer
                                      elementStore:elementStore
                                             query:query
                               excludingAttributes:nil];
    if (rc >= 0) {
      rc = xmlTextWriterEndDocument(writer);
    }
  }
  xmlFreeTextWriter(writer);
  XCTAssertTrue(rc >= 0);
  return doc;
}

- (void)testXPathExtensionFunctions
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  snapshot.label = @"Hello World";
  snapshot.value = @"One-Two-Three";

  xmlDocPtr doc = [self documentForSnapshot:snapshot query:@"//*[@label and @name and @value]"];

  @try {
    XCTAssertTrue([self xpathBooleanResultForQuery:@"matches(//XCUIElementTypeOther/@label, 'Hello.*')" document:doc]);
    XCTAssertFalse([self xpathBooleanResultForQuery:@"matches(//XCUIElementTypeOther/@label, 'hello.*')" document:doc]);
    XCTAssertTrue([self xpathBooleanResultForQuery:@"matches(//XCUIElementTypeOther/@label, 'hello.*', 'i')" document:doc]);
    XCTAssertTrue([self xpathBooleanResultForQuery:@"ends-with(//XCUIElementTypeOther/@name, 'Name')" document:doc]);
    XCTAssertFalse([self xpathBooleanResultForQuery:@"ends-with(//XCUIElementTypeOther/@name, 'Foo')" document:doc]);
    XCTAssertEqualObjects([self xpathStringResultForQuery:@"lower-case(//XCUIElementTypeOther/@label)" document:doc], @"hello world");
    XCTAssertEqualObjects([self xpathStringResultForQuery:@"upper-case(//XCUIElementTypeOther/@name)" document:doc], @"TESTNAME");
    XCTAssertEqualObjects([self xpathStringResultForQuery:@"replace(//XCUIElementTypeOther/@value, '-', '_')" document:doc], @"One_Two_Three");
    XCTAssertEqualObjects([self xpathStringResultForQuery:@"string-join(tokenize(//XCUIElementTypeOther/@value, '-'), '|')" document:doc], @"One|Two|Three");
  } @finally {
    xmlFreeDoc(doc);
  }
}

- (void)testInvalidXPathExtensionRegexp
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  snapshot.label = @"Hello World";
  snapshot.value = @"One-Two-Three";

  xmlDocPtr doc = [self documentForSnapshot:snapshot query:@"//*[@label and @name and @value]"];

  @try {
    [self assertXPathEvaluationFailsForQuery:@"matches(//XCUIElementTypeOther/@label, '[')" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"replace(//XCUIElementTypeOther/@label, '[', '')" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"tokenize(//XCUIElementTypeOther/@value, '[')" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"matches(//XCUIElementTypeOther/@label, 'a', 'z')" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"//XCUIElementTypeOther[matches(@label, '[')]" document:doc];
  } @finally {
    xmlFreeDoc(doc);
  }
}

- (void)assertXPathEvaluationFailsForQuery:(NSString *)query document:(xmlDocPtr)doc
{
  xmlXPathObjectPtr queryResult = [FBXPath evaluate:query document:doc contextNode:NULL];
  @try {
    XCTAssertEqual(NULL, queryResult);
  } @finally {
    if (NULL != queryResult) {
      xmlXPathFreeObject(queryResult);
    }
  }
}

- (void)testInvalidXPathExtensionFunctionArity
{
  XCElementSnapshotDouble *snapshot = [XCElementSnapshotDouble new];
  snapshot.label = @"Hello World";
  snapshot.value = @"One-Two-Three";

  xmlDocPtr doc = [self documentForSnapshot:snapshot query:@"//*[@label and @name and @value]"];

  @try {
    [self assertXPathEvaluationFailsForQuery:@"matches(//XCUIElementTypeOther/@label)" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"lower-case()" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"string-join(//XCUIElementTypeOther/@label)" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"replace(//XCUIElementTypeOther/@label, '-')" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"//XCUIElementTypeOther[matches(@label)]" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"//XCUIElementTypeOther[lower-case()]" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"//XCUIElementTypeOther[string-join(@label)]" document:doc];
    [self assertXPathEvaluationFailsForQuery:@"//XCUIElementTypeOther[replace(@label, '-')]" document:doc];
  } @finally {
    xmlFreeDoc(doc);
  }
}

@end
