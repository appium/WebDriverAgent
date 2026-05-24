/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"
#endif

#import <libxml/xpath.h>

#ifdef __clang__
#pragma clang diagnostic pop
#endif

NS_ASSUME_NONNULL_BEGIN

@interface FBXPathEvaluationContext : NSObject

- (void)cleanup;

@end

@interface FBXPathExtensions : NSObject

/**
 Registers XPath 2-compatible extension functions on the given libxml2 context
 and attaches an evaluation context used to manage temporary documents.

 @param xpathCtx libxml2 XPath context
 @return evaluation context that must be cleaned up after expression evaluation
 */
+ (FBXPathEvaluationContext *)configureXPathContext:(xmlXPathContextPtr)xpathCtx;

@end

NS_ASSUME_NONNULL_END
