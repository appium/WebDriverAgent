/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXPathExtensions.h"

#import <libxml/xpathInternals.h>

static void FBRegisterXPathExtensions(xmlXPathContextPtr xpathCtx);

static NSString *const FBXPathTokenSequenceSeparator = @"\x1E";
static const NSRegularExpressionOptions FBXPathNoRegexOptions = (NSRegularExpressionOptions)0;
static const NSMatchingOptions FBXPathNoMatchingOptions = (NSMatchingOptions)0;

static void FBXPathSetInvalidArityError(xmlXPathParserContextPtr ctxt)
{
  if (NULL == ctxt) {
    return;
  }
  xmlXPatherror(ctxt, __FILE__, __LINE__, XPATH_INVALID_ARITY);
  ctxt->error = XPATH_INVALID_ARITY;
}

static NSString *FBXPathStringFromUTF8Bytes(const xmlChar *bytes)
{
  if (NULL == bytes) {
    return nil;
  }
  return [NSString stringWithUTF8String:(const char *)bytes];
}

@implementation FBXPathExtensions

+ (void)registerFunctionsWithContext:(xmlXPathContextPtr)xpathCtx
{
  FBRegisterXPathExtensions(xpathCtx);
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
  NSRegularExpressionOptions options = FBXPathNoRegexOptions;
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
  // xmlXPathWrapString takes ownership of the buffer passed to xmlXPathReturnString.
  xmlXPathReturnString(ctxt, copiedValue);
}

static NSArray<NSString *> *FBXPathTokenizeString(NSString *input, NSString *pattern)
{
  if (0 == input.length) {
    return @[];
  }

  if (nil == pattern) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\S+"
                                                                           options:FBXPathNoRegexOptions
                                                                             error:nil];
    if (nil == regex) {
      return @[];
    }
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    [regex enumerateMatchesInString:input
                            options:FBXPathNoMatchingOptions
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
                                                                         options:FBXPathNoRegexOptions
                                                                           error:nil];
  if (nil == regex) {
    return @[];
  }

  NSMutableArray<NSString *> *tokens = [NSMutableArray array];
  __block NSUInteger lastIndex = 0;
  [regex enumerateMatchesInString:input
                          options:FBXPathNoMatchingOptions
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

static NSArray<NSString *> *FBXPathPartsFromXPathObject(xmlXPathObjectPtr sequence)
{
  if (sequence->type == XPATH_NODESET && NULL != sequence->nodesetval) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (int index = 0; index < sequence->nodesetval->nodeNr; index++) {
      xmlChar *content = xmlNodeGetContent(sequence->nodesetval->nodeTab[index]);
      if (NULL != content) {
        NSString *part = FBXPathStringFromUTF8Bytes(content);
        xmlFree(content);
        if (nil != part) {
          [parts addObject:part];
        }
      }
    }
    return parts.copy;
  }

  xmlChar *asString = xmlXPathCastToString(sequence);
  if (NULL == asString) {
    return @[];
  }
  NSString *value = FBXPathStringFromUTF8Bytes(asString);
  xmlFree(asString);
  if (nil == value || 0 == value.length) {
    return @[];
  }
  if ([value rangeOfString:FBXPathTokenSequenceSeparator].location != NSNotFound) {
    return [value componentsSeparatedByString:FBXPathTokenSequenceSeparator];
  }
  return @[value];
}

static void fbXPathMatchesFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs < 2 || nargs > 3) {
    FBXPathSetInvalidArityError(ctxt);
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
  NSTextCheckingResult *match = [regex firstMatchInString:input options:FBXPathNoMatchingOptions range:range];
  xmlXPathReturnBoolean(ctxt, nil != match);
}

static void fbXPathEndsWithFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 2) {
    FBXPathSetInvalidArityError(ctxt);
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
    FBXPathSetInvalidArityError(ctxt);
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
    FBXPathSetInvalidArityError(ctxt);
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
    FBXPathSetInvalidArityError(ctxt);
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
                                                     options:FBXPathNoMatchingOptions
                                                       range:range
                                                withTemplate:replacement];
  FBXPathReturnNSString(ctxt, result);
}

static void fbXPathTokenizeFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs < 1 || nargs > 2) {
    FBXPathSetInvalidArityError(ctxt);
    return;
  }

  NSString *pattern = nargs == 2 ? FBXPathPopNSString(ctxt) : nil;
  NSString *input = FBXPathPopNSString(ctxt);
  if (nil == input || xmlXPathCheckError(ctxt)) {
    return;
  }

  NSArray<NSString *> *tokens = FBXPathTokenizeString(input, pattern);
  FBXPathReturnNSString(ctxt, [tokens componentsJoinedByString:FBXPathTokenSequenceSeparator]);
}

static void fbXPathStringJoinFunction(xmlXPathParserContextPtr ctxt, int nargs)
{
  if (nargs != 2) {
    FBXPathSetInvalidArityError(ctxt);
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

  NSString *separator = FBXPathStringFromUTF8Bytes(separatorChars);
  xmlFree(separatorChars);
  if (nil == separator) {
    xmlXPathFreeObject(sequence);
    return;
  }

  NSArray<NSString *> *parts = FBXPathPartsFromXPathObject(sequence);
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
