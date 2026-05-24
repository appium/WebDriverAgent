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

@interface FBXPathExtensions : NSObject

/**
 Registers XPath 2-compatible extension functions on the given libxml2 context.
 */
- (void)registerFunctionsWithContext:(xmlXPathContextPtr)xpathCtx;

/**
 Human-readable message for the most recent XPath extension evaluation failure on this instance,
 for example an invalid regular expression pattern or flags. Nil when no extension error has occurred.
 Scoped to the libxml2 context this instance is registered with; each evaluation should use its own instance.
 */
@property (nonatomic, nullable, readonly, copy) NSString *lastEvaluationError;

@end

NS_ASSUME_NONNULL_END
