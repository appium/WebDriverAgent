/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXPathExtensions.h"

#import <libxml/tree.h>
#import <libxml/xpathInternals.h>

static void FBRegisterXPathExtensions(xmlXPathContextPtr xpathCtx);

@interface FBXPathEvaluationContext ()

@property (nonatomic, strong) NSMutableArray<NSValue *> *temporaryDocuments;

- (void)registerTemporaryDocument:(xmlDocPtr)doc;

@end

@implementation FBXPathEvaluationContext

- (instancetype)init
{
  self = [super init];
  if (self) {
    _temporaryDocuments = [NSMutableArray array];
  }
  return self;
}

- (void)registerTemporaryDocument:(xmlDocPtr)doc
{
  if (NULL != doc) {
    [self.temporaryDocuments addObject:[NSValue valueWithPointer:doc]];
  }
}

- (void)cleanup
{
  for (NSValue *value in self.temporaryDocuments) {
    xmlFreeDoc((xmlDocPtr)value.pointerValue);
  }
  [self.temporaryDocuments removeAllObjects];
}

@end

@implementation FBXPathExtensions

+ (FBXPathEvaluationContext *)configureXPathContext:(xmlXPathContextPtr)xpathCtx
{
  FBXPathEvaluationContext *evalContext = [FBXPathEvaluationContext new];
  xpathCtx->userData = (__bridge void *)evalContext;
  FBRegisterXPathExtensions(xpathCtx);
  return evalContext;
}

@end

static NSString *FBXPathPopNSString(xmlXPathParserContextPtr ctxt)
{
  xmlChar *value = xmlXPathPopString(ctxt);
  if (NULL == value || xmlXPathCheckError(ctxt)) {
    return nil;
  }
  NSString *result = [NSString stringWithUTF8String:(const char *)value];
  xmlFree(value);
  return result;
}

static NSRegularExpressionOptions FBXPathRegexOptionsFromFlags(NSString *flags)
{
  NSRegularExpressionOptions options = 0;
  if (nil != flags && [flags rangeOfString:@"i"].location != NSNotFound) {
    options |= NSRegularExpressionCaseInsensitive;
  }
  return options;
}

static NSRegularExpression *FBXPathRegexWithPattern(NSString *pattern, NSString *flags, NSError **error)
{
  return [NSRegularExpression regularExpressionWithPattern:pattern
                                                   options:FBXPathRegexOptionsFromFlags(flags)
                                                     error:error];
}

static void FBXPathReturnNSString(xmlXPathParserContextPtr ctxt, NSString *value)
{
  if (nil == value) {
    xmlXPathReturnEmptyString(ctxt);
    return;
  }
  xmlChar *copiedValue = xmlStrdup((const xmlChar *)[value UTF8String]);
  if (NULL == copiedValue) {
    xmlXPathReturnEmptyString(ctxt);
    return;
  }
  xmlXPathReturnString(ctxt, copiedValue);
  xmlFree(copiedValue);
}

static xmlXPathObjectPtr FBXPathCreateTokenNodeSet(xmlXPathParserContextPtr ctxt, NSArray<NSString *> *tokens)
{
  xmlDocPtr container = xmlNewDoc(BAD_CAST "1.0");
  xmlNodePtr rootNode = xmlNewNode(NULL, BAD_CAST "tokens");
  xmlDocSetRootElement(container, rootNode);

  xmlXPathObjectPtr result = xmlXPathNewNodeSet(NULL);
  if (NULL == result || NULL == result->nodesetval) {
    xmlFreeDoc(container);
    return result;
  }

  for (NSString *token in tokens) {
    xmlChar *tokenContent = xmlStrdup((const xmlChar *)[token UTF8String]);
    xmlNodePtr tokenNode = xmlNewNode(NULL, BAD_CAST "token");
    xmlNodeSetContent(tokenNode, tokenContent);
    xmlFree(tokenContent);
    xmlAddChild(rootNode, tokenNode);
    xmlXPathNodeSetAdd(result->nodesetval, tokenNode);
  }

  FBXPathEvaluationContext *evalContext = (__bridge FBXPathEvaluationContext *)ctxt->context->userData;
  [evalContext registerTemporaryDocument:container];
  return result;
}

static NSArray<NSString *> *FBXPathTokenizeString(NSString *input, NSString *pattern)
{
  if (0 == input.length) {
    return @[];
  }

  if (nil == pattern) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\S+"
                                                                           options:0
                                                                             error:nil];
    if (nil == regex) {
      return @[];
    }
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    [regex enumerateMatchesInString:input
                            options:0
                              range:NSMakeRange(0, input.length)
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
      if (nil != result) {
        [tokens addObject:[input substringWithRange:result.range]];
      }
    }];
    return tokens.copy;
  }

  if (0 == pattern.length) {
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    [input enumerateSubstringsInRange:NSMakeRange(0, input.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
      if (substring.length > 0) {
        [tokens addObject:substring];
      }
    }];
    return tokens.copy;
  }

  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
  if (nil == regex) {
    return @[];
  }

  NSMutableArray<NSString *> *tokens = [NSMutableArray array];
  __block NSUInteger lastIndex = 0;
  [regex enumerateMatchesInString:input
                          options:0
                            range:NSMakeRange(0, input.length)
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
    if (nil == result) {
      return;
    }
    if (result.range.location > lastIndex) {
      NSString *token = [input substringWithRange:NSMakeRange(lastIndex, result.range.location - lastIndex)];
      if (token.length > 0) {
        [tokens addObject:token];
      }
    }
    lastIndex = NSMaxRange(result.range);
  }];
  if (lastIndex < input.length) {
    NSString *token = [input substringFromIndex:lastIndex];
    if (token.length > 0) {
      [tokens addObject:token];
    }
  }
  return tokens.copy;
}

static void fbXPathMatchesFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs < 2 || nargs > 3) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *flags = nargs == 3 ? FBXPathPopNSString(ctxt) : nil;
  NSString *pattern = FBXPathPopNSString(ctxt);
  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == pattern || nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  NSError *error = nil;
  NSRegularExpression *regex = FBXPathRegexWithPattern(pattern, flags, &error);
  if (nil == regex) {
    xmlXPathReturnBoolean(ctxt, 0);
    return;
  }

  NSRange range = NSMakeRange(0, input.length);
  NSTextCheckingResult *match = [regex firstMatchInString:input options:0 range:range];
  xmlXPathReturnBoolean(ctxt, nil != match);
}

static void fbXPathEndsWithFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 2) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *suffix = FBXPathPopNSString(ctxt);
  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == suffix || nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  xmlXPathReturnBoolean(ctxt, [input hasSuffix:suffix]);
}

static void fbXPathLowerCaseFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 1) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  FBXPathReturnNSString(ctxt, input.lowercaseString);
}

static void fbXPathUpperCaseFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 1) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  FBXPathReturnNSString(ctxt, input.uppercaseString);
}

static void fbXPathReplaceFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs < 3 || nargs > 4) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *flags = nargs == 4 ? FBXPathPopNSString(ctxt) : nil;
  NSString *replacement = FBXPathPopNSString(ctxt);
  NSString *pattern = FBXPathPopNSString(ctxt);
  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == replacement || nil == pattern || nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  NSError *error = nil;
  NSRegularExpression *regex = FBXPathRegexWithPattern(pattern, flags, &error);
  if (nil == regex) {
    FBXPathReturnNSString(ctxt, input);
    return;
  }

  NSRange range = NSMakeRange(0, input.length);
  NSString *result = [regex stringByReplacingMatchesInString:input
                                                     options:0
                                                       range:range
                                                withTemplate:replacement];
  FBXPathReturnNSString(ctxt, result);
}

static void fbXPathTokenizeFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs < 1 || nargs > 2) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  NSString *pattern = nargs == 2 ? FBXPathPopNSString(ctxt) : nil;
  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  NSArray<NSString *> *tokens = FBXPathTokenizeString(input, pattern);
  xmlXPathObjectPtr result = FBXPathCreateTokenNodeSet(ctxt, tokens);
  if (NULL == result) {
    xmlXPathReturnEmptyNodeSet(ctxt);
    return;
  }
  valuePush(ctxt, result);
}

static void fbXPathStringJoinFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 2) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  xmlChar *separatorChars = xmlXPathPopString(ctxt);
  xmlXPathObjectPtr sequence = valuePop(ctxt);
  if (xmlXPathCheckError(ctxt) || NULL == sequence || NULL == separatorChars) {
    if (NULL != separatorChars) {
      xmlFree(separatorChars);
    }
    if (NULL != sequence) {
      xmlXPathFreeObject(sequence);
    }
    return;
  }

  NSString *separator = [NSString stringWithUTF8String:(const char *)separatorChars];
  xmlFree(separatorChars);

  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  if (sequence->type == XPATH_NODESET && NULL != sequence->nodesetval) {
    for (int index = 0; index < sequence->nodesetval->nodeNr; index++) {
      xmlChar *content = xmlNodeGetContent(sequence->nodesetval->nodeTab[index]);
      if (NULL != content) {
        [parts addObject:[NSString stringWithUTF8String:(const char *)content]];
        xmlFree(content);
      }
    }
  } else {
    xmlChar *asString = xmlXPathCastToString(sequence);
    if (NULL != asString) {
      [parts addObject:[NSString stringWithUTF8String:(const char *)asString]];
      xmlFree(asString);
    }
  }
  xmlXPathFreeObject(sequence);

  FBXPathReturnNSString(ctxt, [parts componentsJoinedByString:separator]);
}

static void FBRegisterXPathExtensions(xmlXPathContextPtr xpathCtx)
{
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "matches", fbXPathMatchesFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "ends-with", fbXPathEndsWithFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "lower-case", fbXPathLowerCaseFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "upper-case", fbXPathUpperCaseFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "replace", fbXPathReplaceFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "tokenize", fbXPathTokenizeFunction);
  xmlXPathRegisterFunc(xpathCtx, BAD_CAST "string-join", fbXPathStringJoinFunction);
}
